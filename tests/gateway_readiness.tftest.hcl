mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name             = "bt-test"
  kms_key_arn                 = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id                      = "vpc-0123456789abcdef0"
  private_subnet_ids          = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  ecs_cluster_arn             = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name            = "bt-test"
  container_image             = "public.ecr.aws/braintrust/gateway:test"
  target_group_arn            = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/1234567890123456"
  alb_security_group_id       = "sg-0123456789abcdef2"
  gateway_http_listener_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
  gateway_url                 = "http://gateway.internal"
  braintrust_api_url          = "http://api.internal"
  use_redis_replication_group = false
  redis_host                  = "redis.internal"
  redis_port                  = 6379
  redis_security_group_id     = "sg-0123456789abcdef1"
}

run "gateway_waits_for_healthy_deployment" {
  command = plan
  module {
    source = "./modules/gateway-ecs"
  }

  assert {
    condition = (
      aws_ecs_service.gateway.wait_for_steady_state &&
      aws_ecs_service.gateway.deployment_circuit_breaker[0].enable &&
      aws_ecs_service.gateway.desired_count >= 1
    )
    error_message = "The readiness gate requires a nonempty stable ECS service with deployment failure detection."
  }

  assert {
    condition = one([
      for env in jsondecode(aws_ecs_task_definition.gateway.container_definitions)[0].environment : env.value
      if env.name == "BRAINTRUST_API_URL"
    ]) == "http://api.internal"
    error_message = "Gateway API calls must use the supplied private API address."
  }

  assert {
    condition     = output.gateway_url == "http://gateway.internal"
    error_message = "The readiness output must preserve the gateway endpoint."
  }
}
