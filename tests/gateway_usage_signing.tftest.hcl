# Check the environment delivered to the Gateway application container.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-test-brainstore"
  deployment_name                       = "bt-test"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id                                = "vpc-0123456789abcdef0"
  private_subnet_ids                    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  ecs_cluster_arn                       = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                      = "bt-test"
  container_image                       = "public.ecr.aws/braintrust/gateway:v2.22.0"
  target_group_arn                      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/1234567890123456"
  alb_security_group_id                 = "sg-0123456789abcdef2"
  gateway_http_listener_arn             = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
  gateway_url                           = "http://gateway.internal"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  redis_port                            = 6379
  redis_security_group_id               = "sg-0123456789abcdef1"
  brainstore_license_key_secret_arn     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  brainstore_license_key_secret_version = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
}

run "private_ingestion_does_not_enable_workload_signing" {
  command = plan
  module { source = "./modules/gateway-ecs" }

  assert {
    condition     = length(aws_iam_role_policy.usage_signing) == 0
    error_message = "Private ingestion must not grant KMS signing by default."
  }

  assert {
    condition = alltrue([
      for container in jsondecode(aws_ecs_task_definition.gateway.container_definitions) :
      alltrue([for env in container.environment : !contains([
        "GATEWAY_USAGE_SIGNING_KEY_ARN", "GATEWAY_USAGE_HOSTED_API_URLS"
      ], env.name)]) if container.name == "gateway"
    ])
    error_message = "Private ingestion must not enable workload credentials by default."
  }
}

run "signed_usage_uses_the_private_callback_and_scoped_key" {
  command = plan
  module { source = "./modules/gateway-ecs" }

  variables {
    braintrust_api_url = "http://api.internal"
    usage_signing_key = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/usage-signer"
    }
  }

  assert {
    condition = alltrue([
      for name, value in {
        GATEWAY_USAGE_SIGNING_KEY_ARN = var.usage_signing_key.arn
        GATEWAY_USAGE_HOSTED_API_URLS = var.braintrust_api_url
        OVERRIDE_BRAINTRUST_API_URL   = var.braintrust_api_url
      } :
      one([for container in jsondecode(aws_ecs_task_definition.gateway.container_definitions) :
        one([for env in container.environment : env.value if env.name == name])
        if container.name == "gateway"
      ]) == value
    ])
    error_message = "Signed usage must target the same private API as Gateway callbacks."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.usage_signing[0].policy).Statement[0].Resource == var.usage_signing_key.arn &&
      toset(jsondecode(aws_iam_role_policy.usage_signing[0].policy).Statement[0].Action) == toset(["kms:Sign"]) &&
      jsondecode(aws_iam_role_policy.usage_signing[0].policy).Statement[0].Condition.StringEquals["kms:SigningAlgorithm"] == "RSASSA_PKCS1_V1_5_SHA_256"
    )
    error_message = "The task may only sign with the configured KMS key using RS256."
  }
}

run "signed_usage_respects_an_explicit_callback_override" {
  command = plan
  module { source = "./modules/gateway-ecs" }

  variables {
    braintrust_api_url = "http://api.internal"
    usage_signing_key = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/usage-signer"
    }
    extra_env_vars = {
      OVERRIDE_BRAINTRUST_API_URL = "http://override.internal"
    }
  }

  assert {
    condition = one([
      for container in jsondecode(aws_ecs_task_definition.gateway.container_definitions) :
      one([for env in container.environment : env.value if env.name == "GATEWAY_USAGE_HOSTED_API_URLS"])
      if container.name == "gateway"
    ]) == var.extra_env_vars.OVERRIDE_BRAINTRUST_API_URL
    error_message = "The usage destination must follow an explicit API callback override."
  }
}
