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

run "gateway_otlp_defaults_to_pulse" {
  command = plan
  module {
    source = "./modules/gateway-ecs"
  }

  assert {
    condition = [
      for env in jsondecode(aws_ecs_task_definition.gateway.container_definitions)[0].environment : env
      if contains(["OTLP_HTTP_ENDPOINT", "PULSE_URL"], env.name)
    ] == [{ name = "PULSE_URL", value = "https://pulse.braintrust.dev" }]
    error_message = "Without monitoring_telemetry_url, the gateway must send to Pulse directly, with no OTLP_HTTP_ENDPOINT override."
  }
}

run "gateway_otlp_uses_monitoring_telemetry_url" {
  command = plan
  module {
    source = "./modules/gateway-ecs"
  }

  variables {
    monitoring_telemetry_url = "https://pulse.example.com/prefix/"
  }

  assert {
    condition = [
      for env in jsondecode(aws_ecs_task_definition.gateway.container_definitions)[0].environment : env
      if contains(["OTLP_HTTP_ENDPOINT", "PULSE_URL"], env.name)
    ] == [{ name = "PULSE_URL", value = "https://pulse.example.com/prefix/" }]
    error_message = "With monitoring_telemetry_url, the gateway must set PULSE_URL, with no OTLP_HTTP_ENDPOINT override."
  }
}

run "gateway_otlp_uses_datadog_agent_with_internal_observability" {
  command = plan
  module {
    source = "./modules/gateway-ecs"
  }

  variables {
    monitoring_telemetry_url                  = "https://pulse.example.com/prefix"
    internal_observability_enabled            = true
    internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
    internal_observability_env_name           = "test"
    internal_observability_region             = "us5"
  }

  assert {
    condition = one([
      for env in jsondecode(aws_ecs_task_definition.gateway.container_definitions)[0].environment : env.value
      if env.name == "OTLP_HTTP_ENDPOINT"
    ]) == "http://localhost:4318"
    error_message = "With internal observability, gateway OTLP must go to the local Datadog agent."
  }
}
