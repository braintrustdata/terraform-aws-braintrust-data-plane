# Focused replacement-order fixture for the fixed-name gateway ECS service.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

override_resource {
  target = aws_iam_role.task_execution
  values = {
    arn  = "arn:aws:iam::123456789012:role/bt-test-gateway-task-exec"
    id   = "bt-test-gateway-task-exec"
    name = "bt-test-gateway-task-exec"
  }
}

override_resource {
  target = aws_iam_role.task
  values = {
    arn  = "arn:aws:iam::123456789012:role/bt-test-gateway-task"
    id   = "bt-test-gateway-task"
    name = "bt-test-gateway-task"
  }
}

variables {
  deployment_name             = "bt-test"
  kms_key_arn                 = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id                      = "vpc-test"
  private_subnet_ids          = ["subnet-a", "subnet-b"]
  ecs_cluster_arn             = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name            = "bt-test"
  container_image             = "public.ecr.aws/braintrust/gateway:test"
  target_group_arn            = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/test"
  alb_security_group_id       = "sg-alb"
  gateway_http_listener_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/test/listener"
  use_redis_replication_group = true
  redis_host                  = "redis.test"
  redis_port                  = 6379
  redis_security_group_id     = "sg-redis"
}

run "seed_mocked_gateway_state" {
  command = apply

  module {
    source = "./modules/gateway-ecs"
  }
}

run "force_fixed_name_gateway_replacement" {
  command = plan

  module {
    source = "./modules/gateway-ecs"
  }

  plan_options {
    refresh = false
    replace = [
      aws_ecs_service.gateway,
    ]
  }
}
