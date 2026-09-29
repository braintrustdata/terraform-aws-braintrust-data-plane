mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                         = "bt-test"
  kms_key_arn                             = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  vpc_id                                  = "vpc-11111111111111111"
  private_subnet_ids                      = ["subnet-11111111111111111", "subnet-22222222222222222"]
  ecs_cluster_arn                         = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                        = "bt-test"
  container_image                         = "public.ecr.aws/braintrust/loop-runtime:test"
  target_group_arn                        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop/1111111111111111"
  alb_security_group_id                   = "sg-11111111111111111"
  loop_runtime_http_listener_arn          = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-loop/1111111111111111/1111111111111111"
  sandbox_egress_gateway_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222"
  database_url_secret_arn                 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn                    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  function_tools_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  brainstore_s3_bucket_name               = "bt-test-brainstore"
  brainstore_s3_bucket_arn                = "arn:aws:s3:::bt-test-brainstore"
  code_bundle_bucket                      = "bt-test-code-bundles"
  code_bundle_bucket_arn                  = "arn:aws:s3:::bt-test-code-bundles"
  brainstore_reader_url                   = "http://brainstore.internal:4000"
  ai_proxy_url                            = "https://api.example.com/v1/proxy"
  braintrust_api_url                      = "https://api.example.com"
  sandbox_egress_gateway_authorized_security_groups = {
    "Loop Sandbox Egress Gateway" = "sg-22222222222222222"
  }
}

run "serves_sandbox_egress_gateway" {
  command = plan
  module {
    source = "./modules/loop-runtime-ecs"
  }

  assert {
    condition = contains(
      [for mapping in jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].portMappings : mapping.containerPort],
      4002,
    )
    error_message = "The Loop runtime container must expose the egress gateway port."
  }

  assert {
    condition     = local.merged_env_vars["LOOP_RUNTIME_SANDBOX_FORWARD_PROXY_LISTEN"] == "0.0.0.0:4002"
    error_message = "The runtime must listen for sandbox egress on port 4002."
  }

  assert {
    condition = anytrue([
      for lb in aws_ecs_service.loop_runtime.load_balancer :
      lb.target_group_arn == var.sandbox_egress_gateway_target_group_arn && lb.container_port == 4002 && lb.container_name == "loop-runtime"
    ])
    error_message = "The ECS service must register port 4002 with the egress gateway target group."
  }

  assert {
    condition = anytrue([
      for lb in aws_ecs_service.loop_runtime.load_balancer :
      lb.target_group_arn == var.target_group_arn && lb.container_port == 4001
    ])
    error_message = "The ECS service must keep port 4001 registered with the ALB target group."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.task_from_sandbox_egress_gateway["Loop Sandbox Egress Gateway"].referenced_security_group_id == "sg-22222222222222222"
      && aws_vpc_security_group_ingress_rule.task_from_sandbox_egress_gateway["Loop Sandbox Egress Gateway"].from_port == 4002
      && aws_vpc_security_group_ingress_rule.task_from_sandbox_egress_gateway["Loop Sandbox Egress Gateway"].to_port == 4002
    )
    error_message = "Only authorized egress gateway security groups may reach the tasks on port 4002."
  }
}
