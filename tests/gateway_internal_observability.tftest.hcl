mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                           = "bt-test"
  kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  vpc_id                                    = "vpc-11111111111111111"
  private_subnet_ids                        = ["subnet-11111111111111111", "subnet-22222222222222222"]
  ecs_cluster_arn                           = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                          = "bt-test"
  container_image                           = "public.ecr.aws/braintrust/gateway:test"
  target_group_arn                          = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-gateway/1111111111111111"
  alb_security_group_id                     = "sg-11111111111111111"
  gateway_http_listener_arn                 = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-gateway/1111111111111111/1111111111111111"
  use_redis_replication_group               = false
  redis_host                                = "redis.example.internal"
  redis_port                                = 6379
  redis_security_group_id                   = "sg-22222222222222222"
  internal_observability_enabled            = true
  internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
  internal_observability_env_name           = "test"
  internal_observability_region             = "us5"
}

run "datadog_agent_disables_apm" {
  command = plan

  module {
    source = "./modules/gateway-ecs"
  }

  assert {
    condition = (
      [for container in jsondecode(aws_ecs_task_definition.gateway.container_definitions) : container.name] == ["gateway", "datadog-agent"] &&
      { for env in jsondecode(aws_ecs_task_definition.gateway.container_definitions)[1].environment : env.name => env.value if contains(["DD_APM_ENABLED", "DD_OTLP_CONFIG_TRACES_ENABLED", "DD_OTLP_CONFIG_LOGS_ENABLED"], env.name) } == { DD_APM_ENABLED = "false", DD_OTLP_CONFIG_TRACES_ENABLED = "false", DD_OTLP_CONFIG_LOGS_ENABLED = "true" }
    )
    error_message = "The gateway Datadog agent must disable APM and OTLP traces while keeping OTLP logs."
  }
}
