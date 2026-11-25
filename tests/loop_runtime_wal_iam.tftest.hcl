mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  deployment_name                   = "bt-test"
  kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  vpc_id                            = "vpc-11111111111111111"
  private_subnet_ids                = ["subnet-11111111111111111", "subnet-22222222222222222"]
  ecs_cluster_arn                   = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                  = "bt-test"
  container_image                   = "public.ecr.aws/braintrust/loop-runtime:test"
  target_group_arn                  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop/1111111111111111"
  alb_security_group_id             = "sg-11111111111111111"
  loop_runtime_http_listener_arn    = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-loop/1111111111111111/1111111111111111"
  database_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  redis_url_secret_version_id       = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  function_tools_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  brainstore_s3_bucket_name         = "bt-test-brainstore"
  brainstore_s3_bucket_arn          = "arn:aws:s3:::bt-test-brainstore"
  code_bundle_bucket                = "bt-test-code-bundles"
  code_bundle_bucket_arn            = "arn:aws:s3:::bt-test-code-bundles"
  brainstore_reader_url             = "http://brainstore.internal:4000"
  ai_proxy_url                      = "https://api.example.com/v1/proxy"
  braintrust_api_url                = "https://api.example.com"

  sandbox_egress_gateway_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222"
}

run "wal_markers_with_redis_locks" {
  command = plan
  module { source = "./modules/loop-runtime-ecs" }
  variables { brainstore_object_store_locks = false }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.brainstore_s3_access.policy).Statement : statement
      if statement.Effect == "Allow" &&
      toset(statement.Action) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]) &&
      statement.Resource == ["${var.brainstore_s3_bucket_arn}/brainstore/wal/active-writes/*/usage_events:*/*"] &&
      !can(statement.Condition)
    ]) == 1
    error_message = "Loop must be able to create and conditionally delete active-write WAL markers, including object versions."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.brainstore_s3_access.policy).Statement : statement
      if statement.Resource == ["${var.brainstore_s3_bucket_arn}/brainstore/wal/object-store-objects/*"] &&
      statement.Action == ["s3:PutObject"]
    ]) == 1
    error_message = "WAL payload objects must remain write-only."
  }

  # Event and usage appends read or create WAL token files on a Redis miss and
  # check the migration flag; without these grants they fail with AccessDenied.
  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.brainstore_s3_access.policy).Statement : statement
      if statement.Resource == ["${var.brainstore_s3_bucket_arn}/brainstore/wal/wal_token/*"] &&
      toset(statement.Action) == toset(["s3:GetObject", "s3:PutObject"])
    ]) == 1
    error_message = "Loop must be able to read and create WAL token files."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.brainstore_s3_access.policy).Statement : statement
      if statement.Resource == ["${var.brainstore_s3_bucket_arn}/brainstore/wal/flags/wal_token_fully_migrated"] &&
      statement.Action == ["s3:GetObject"]
    ]) == 1
    error_message = "Loop must be able to read the WAL token migration flag."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.brainstore_s3_access.policy).Statement : statement
      if statement.Action == ["s3:ListBucket"] &&
      try(toset(statement.Condition.StringLike["s3:prefix"]), toset([])) == toset([
        "brainstore/wal/recently-updated/*",
        "brainstore/wal/wal_token/*",
        "brainstore/wal/flags/wal_token_fully_migrated",
      ])
    ]) == 1
    error_message = "Missing WAL markers, token files, and migration flags must return 404 rather than 403."
  }
}

run "wal_markers_with_object_store_locks" {
  command = plan
  module { source = "./modules/loop-runtime-ecs" }
  variables { brainstore_object_store_locks = true }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.brainstore_s3_access.policy).Statement : statement
      if statement.Effect == "Allow" &&
      toset(statement.Action) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]) &&
      statement.Resource == ["${var.brainstore_s3_bucket_arn}/brainstore/wal/active-writes/*/usage_events:*/*"] &&
      !can(statement.Condition)
    ]) == 1
    error_message = "Loop must be able to create and conditionally delete active-write WAL markers, including object versions."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.brainstore_s3_access.policy).Statement : statement
      if statement.Resource == ["${var.brainstore_s3_bucket_arn}/brainstore/wal/object-store-objects/*"] &&
      statement.Action == ["s3:PutObject"]
    ]) == 1
    error_message = "WAL payload objects must remain write-only."
  }
}

run "gateway_usage_markers" {
  command = plan
  module { source = "./modules/gateway-ecs" }
  variables {
    redis_port                = 6379
    gateway_http_listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
    gateway_url               = "http://gateway.internal"
    redis_security_group_id   = "sg-0123456789abcdef1"
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.usage_event_wal_markers.policy).Statement == [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]
      Resource = ["${var.brainstore_s3_bucket_arn}/brainstore/wal/active-writes/*/usage_events:*/*"]
    }]
    error_message = "Gateway WAL marker access must be restricted to usage-event markers."
  }
}

run "gateway_managed_bucket_kms" {
  command = plan
  module { source = "./modules/gateway-ecs" }
  variables {
    redis_port                = 6379
    gateway_http_listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
    gateway_url               = "http://gateway.internal"
    redis_security_group_id   = "sg-0123456789abcdef1"
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.usage_event_kms_access.policy).Statement == [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = [var.kms_key_arn]
      Condition = {
        StringEquals = { "kms:ViaService" = "s3.us-east-1.amazonaws.com" }
      }
    }]
    error_message = "The gateway task role must receive only S3-mediated data-key and decrypt access to the managed bucket key."
  }
}

run "gateway_external_bucket_kms" {
  command = plan
  module { source = "./modules/gateway-ecs" }
  variables {
    redis_port                       = 6379
    gateway_http_listener_arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
    gateway_url                      = "http://gateway.internal"
    redis_security_group_id          = "sg-0123456789abcdef1"
    brainstore_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/33333333-3333-3333-3333-333333333333"
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.usage_event_kms_access.policy).Statement == [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
      Resource = [var.brainstore_s3_bucket_kms_key_arn]
      Condition = {
        StringEquals = { "kms:ViaService" = "s3.us-east-1.amazonaws.com" }
      }
    }]
    error_message = "An external bucket must select its supplied encryption key without granting access to the managed bucket key."
  }
}
