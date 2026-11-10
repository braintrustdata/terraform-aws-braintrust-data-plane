# Check the environment delivered to the Gateway application container.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
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

run "gateway_receives_named_org_and_id_allowlist" {
  command = plan
  module { source = "./modules/gateway-ecs" }

  variables {
    org_name        = "test-org"
    allowed_org_ids = "00000000-0000-4000-8000-000000000001,00000000-0000-4000-8000-000000000002"
  }

  assert {
    condition = alltrue([
      for name, value in { ORG_NAME = var.org_name, ALLOWED_ORG_IDS = var.allowed_org_ids } :
      one([for container in jsondecode(aws_ecs_task_definition.gateway.container_definitions) :
        one([for env in container.environment : env.value if env.name == name])
        if container.name == "gateway"
      ]) == value
    ])
    error_message = "The Gateway task must receive the configured organization name and complete ID allowlist."
  }
}
