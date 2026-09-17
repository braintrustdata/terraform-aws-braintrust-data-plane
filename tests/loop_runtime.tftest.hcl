# Verify Loop receives the same organization configuration as the other services.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                = "bt-test"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                         = "vpc-12345678"
  private_subnet_ids             = ["subnet-12345678", "subnet-87654321"]
  ecs_cluster_arn                = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name               = "bt-test"
  container_image                = "public.ecr.aws/braintrust/loop-runtime:test"
  ephemeral_storage_gib          = 21
  target_group_arn               = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test/0000000000000000"
  alb_security_group_id          = "sg-12345678"
  loop_runtime_http_listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test/0000000000000000/0000000000000000"
  database_url_secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
  redis_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-redis"
  function_tools_secret_arn      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-function-tools"
  brainstore_s3_bucket_name      = "bt-test-brainstore"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
  code_bundle_bucket             = "bt-test-code-bundles"
  code_bundle_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
  brainstore_reader_url          = "http://brainstore.example.test"
  ai_proxy_url                   = "https://ai-proxy.example.test"
  braintrust_api_url             = "https://api.example.test"
  org_name                       = "test-org"
  allowed_org_ids                = "00000000-0000-4000-8000-000000000001"
}

run "loop_runtime_uses_shared_org_configuration" {
  command = plan

  module {
    source = "./modules/loop-runtime-ecs"
  }

  assert {
    condition     = local.merged_env_vars.ORG_NAME == "test-org"
    error_message = "Loop ORG_NAME must use the shared braintrust_org_name value."
  }

  assert {
    condition     = local.merged_env_vars.ALLOWED_ORG_IDS == "00000000-0000-4000-8000-000000000001"
    error_message = "Loop ALLOWED_ORG_IDS must use the shared allowed_org_ids value."
  }
}
