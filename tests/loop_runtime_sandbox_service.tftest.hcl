mock_provider "aws" {
  source = "./tests/mocks/aws"
}


variables {
  deployment_name                = "bt-test"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  vpc_id                         = "vpc-11111111111111111"
  private_subnet_ids             = ["subnet-11111111111111111", "subnet-22222222222222222"]
  ecs_cluster_arn                = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name               = "bt-test"
  container_image                = "public.ecr.aws/braintrust/loop-runtime:test"
  target_group_arn               = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop/1111111111111111"
  alb_security_group_id          = "sg-11111111111111111"
  loop_runtime_http_listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-loop/1111111111111111/1111111111111111"
  database_url_secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  function_tools_secret_arn      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  brainstore_s3_bucket_name      = "bt-test-brainstore"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
  code_bundle_bucket             = "bt-test-code-bundles"
  code_bundle_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
  brainstore_reader_url          = "http://brainstore.internal:4000"
  ai_proxy_url                   = "https://api.example.com/v1/proxy"
  braintrust_api_url             = "https://api.example.com"

  sandbox_egress_gateway_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222"
  sandbox_env_vars = {
    EXO_SANDBOX_PROVIDER                    = "aws-lambda-microvm"
    EXO_SANDBOX_IMAGE                       = "lambda-microvm"
    LOOP_RUNTIME_SANDBOX_EGRESS_GATEWAY_URL = "http://vpce-example.vpce.amazonaws.com:4002"
  }
}

run "lambda_only_has_no_tls_or_feature_flag_setup" {
  command = plan
  module {
    source = "./modules/loop-runtime-ecs"
  }
  assert {
    condition = (
      length(jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)) == 1 &&
      length(aws_ecs_task_definition.loop_runtime.volume) == 0 &&
      length(local.loop_runtime_container_definition.mountPoints) == 0 &&
      length(local.loop_runtime_container_definition.dependsOn) == 0 &&
      local.merged_env_vars.EXO_SANDBOX_PROVIDER == "aws-lambda-microvm" &&
      local.merged_env_vars.EXO_SANDBOX_IMAGE == "lambda-microvm" &&
      !contains(keys(local.merged_env_vars), "EXO_SANDBOX_SERVICE_IMAGE") &&
      !contains(keys(local.merged_env_vars), "LAUNCHDARKLY_ENABLED")
    )
    error_message = "Lambda-only tasks must retain their container, empty volumes, provider and guest image."
  }
  assert {
    condition = (
      length(jsondecode(aws_iam_role_policy.task_execution_secrets.policy).Statement[0].Resource) == 3 &&
      length(jsondecode(aws_iam_role_policy.task_execution_secrets.policy).Statement) == 2
    )
    error_message = "Lambda-only execution roles must not gain TLS or feature-flag secret permissions."
  }
}

run "both_backends_use_separate_images_and_private_proxy_paths" {
  command = plan
  module {
    source = "./modules/loop-runtime-ecs"
  }
  variables {
    sandbox_service = {
      endpoint              = "https://nodes.bt-test.sandbox.internal:9400"
      image                 = "public.ecr.aws/braintrust/codex-runtime:test"
      egress_gateway_url    = "http://loop-egress.example.internal:4002"
      client_tls_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:sandbox-client"
      vcpu_count            = 2
      memory_mib            = 4096
    }
    feature_flags_secret = {
      secret_arn  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:feature-flags"
      kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
    }
  }
  assert {
    condition = (
      local.merged_env_vars.EXO_SANDBOX_PROVIDER == "aws-lambda-microvm" &&
      local.merged_env_vars.EXO_SANDBOX_IMAGE == "lambda-microvm" &&
      local.merged_env_vars.EXO_SANDBOX_SERVICE_IMAGE == var.sandbox_service.image &&
      local.merged_env_vars.LOOP_RUNTIME_SANDBOX_EGRESS_GATEWAY_URL == "http://vpce-example.vpce.amazonaws.com:4002" &&
      local.merged_env_vars.LOOP_RUNTIME_SANDBOX_SERVICE_EGRESS_GATEWAY_URL == "http://loop-egress.example.internal:4002" &&
      local.merged_env_vars.LOOP_RUNTIME_SANDBOX_EGRESS_MODE == "restricted" &&
      local.merged_env_vars.EXO_SANDBOX_VCPU_COUNT == "2" &&
      local.merged_env_vars.EXO_SANDBOX_MEMORY_MIB == "4096" &&
      local.merged_env_vars.LAUNCHDARKLY_ENABLED == "true"
    )
    error_message = "Both backends must preserve the Lambda defaults while configuring a separate service image and private egress URL."
  }
  assert {
    condition = (
      toset([for volume in aws_ecs_task_definition.loop_runtime.volume : volume.name]) == toset(["sandbox-tls"]) &&
      contains(local.loop_runtime_container_definition.dependsOn, { containerName = "sandbox-tls-init", condition = "SUCCESS" }) &&
      one(local.loop_runtime_container_definition.mountPoints).sourceVolume == "sandbox-tls" &&
      one(local.loop_runtime_container_definition.mountPoints).containerPath == "/etc/sandbox-tls" &&
      one(local.loop_runtime_container_definition.mountPoints).readOnly &&
      local.sandbox_tls_init_containers[0].essential == false &&
      local.sandbox_tls_init_containers[0].secrets == [{ name = "TLS_BUNDLE", valueFrom = var.sandbox_service.client_tls_secret_arn }] &&
      local.merged_env_vars.SANDBOX_SERVICE_TLS_CA == "/etc/sandbox-tls/ca_cert.pem"
    )
    error_message = "Loop must wait for the TLS initialization container and mount its files read-only."
  }
  assert {
    condition = (
      !contains(keys(local.merged_env_vars), "LAUNCHDARKLY_SDK_KEY") &&
      !contains(keys(local.merged_env_vars), "TLS_BUNDLE") &&
      contains(local.container_secrets, { name = "LAUNCHDARKLY_SDK_KEY", valueFrom = var.feature_flags_secret.secret_arn }) &&
      toset(jsondecode(aws_iam_role_policy.task_execution_secrets.policy).Statement[0].Resource) == toset([
        var.database_url_secret_arn,
        var.function_tools_secret_arn,
        var.redis_url_secret_arn,
        var.sandbox_service.client_tls_secret_arn,
        var.feature_flags_secret.secret_arn,
      ]) &&
      jsondecode(aws_iam_role_policy.task_execution_secrets.policy).Statement[2].Resource == var.feature_flags_secret.kms_key_arn &&
      jsondecode(aws_iam_role_policy.task_execution_secrets.policy).Statement[2].Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com" &&
      !strcontains(lower(aws_iam_role_policy.code_bundle_access.policy), "secretsmanager") &&
      !strcontains(lower(aws_iam_role_policy.sandbox.policy), "secretsmanager")
    )
    error_message = "TLS and feature-flag values must use ECS secret injection with access restricted to the execution role."
  }
}

run "service_without_sdk_key_keeps_lambda_as_default" {
  command = plan
  module {
    source = "./modules/loop-runtime-ecs"
  }
  variables {
    sandbox_service = {
      endpoint              = "https://nodes.bt-test.sandbox.internal:9400"
      image                 = "public.ecr.aws/braintrust/codex-runtime:test"
      egress_gateway_url    = "http://loop-egress.example.internal:4002"
      client_tls_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:sandbox-client"
      vcpu_count            = 1
      memory_mib            = 2048
    }
  }
  assert {
    condition = (
      local.merged_env_vars.EXO_SANDBOX_PROVIDER == "aws-lambda-microvm" &&
      contains(keys(local.merged_env_vars), "EXO_SANDBOX_SERVICE_IMAGE") &&
      !contains(keys(local.merged_env_vars), "LAUNCHDARKLY_ENABLED") &&
      alltrue([for secret in local.container_secrets : secret.name != "LAUNCHDARKLY_SDK_KEY"])
    )
    error_message = "Provisioning Sandbox Service must not require a feature-flag key or change the default provider."
  }
}
