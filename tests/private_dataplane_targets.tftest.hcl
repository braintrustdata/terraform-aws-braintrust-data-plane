mock_provider "aws" {
  source = "./tests/mocks/aws"
}

run "gateway_registers_direct_customer_targets" {
  command = plan

  module {
    source = "./modules/gateway-ecs"
  }

  variables {
    deployment_name                           = "bt-test"
    kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/test"
    vpc_id                                    = "vpc-0123456789abcdef0"
    private_subnet_ids                        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_cluster_arn                           = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
    ecs_cluster_name                          = "bt-test"
    container_image                           = "123456789012.dkr.ecr.us-east-1.amazonaws.com/gateway:test"
    target_group_arn                          = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/1234567890123456"
    alb_security_group_id                     = "sg-0123456789abcdef2"
    gateway_http_listener_arn                 = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
    gateway_url                               = "http://gateway.internal"
    use_redis_replication_group               = false
    redis_host                                = "redis.example.internal"
    redis_port                                = 6379
    redis_security_group_id                   = "sg-0123456789abcdef1"
    internal_observability_enabled            = true
    internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
    internal_observability_env_name           = "test"

    additional_target_group_arns = {
      "API" = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/customer/4444444444444444"
    }
    authorized_security_groups = {
      "API" = "sg-44444444444444444"
    }
  }

  assert {
    condition = anytrue([
      for lb in aws_ecs_service.gateway.load_balancer :
      lb.target_group_arn == var.additional_target_group_arns["API"] && lb.container_port == 8080 && lb.container_name == "gateway"
    ])
    error_message = "The service must register its application port with the customer target group."
  }

  assert {
    condition = (
      length(aws_ecs_service.gateway.load_balancer) == 2
      && aws_vpc_security_group_ingress_rule.task_ingress_from_authorized_security_groups["API"].referenced_security_group_id == "sg-44444444444444444"
      && aws_vpc_security_group_ingress_rule.task_ingress_from_authorized_security_groups["API"].from_port == 8080
      && aws_vpc_security_group_ingress_rule.task_ingress_from_authorized_security_groups["API"].to_port == 8080
      && aws_vpc_security_group_ingress_rule.task_ingress_from_authorized_security_groups["API"].ip_protocol == "tcp"
    )
    error_message = "The service must retain existing targets and admit API ALB traffic only on its application port."
  }
}

run "loop_runtime_registers_direct_customer_targets" {
  command = plan

  module {
    source = "./modules/loop-runtime-ecs"
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

    additional_target_group_arns = {
      "API" = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/customer/4444444444444444"
    }
    authorized_security_groups = {
      "API" = "sg-44444444444444444"
    }
  }

  assert {
    condition = anytrue([
      for lb in aws_ecs_service.loop_runtime.load_balancer :
      lb.target_group_arn == var.additional_target_group_arns["API"] && lb.container_port == 4001 && lb.container_name == "loop-runtime"
    ])
    error_message = "The service must register its application port with the customer target group."
  }

  assert {
    condition = (
      length(aws_ecs_service.loop_runtime.load_balancer) == 3
      && aws_vpc_security_group_ingress_rule.task_ingress_from_authorized_security_groups["API"].referenced_security_group_id == "sg-44444444444444444"
      && aws_vpc_security_group_ingress_rule.task_ingress_from_authorized_security_groups["API"].from_port == 4001
      && aws_vpc_security_group_ingress_rule.task_ingress_from_authorized_security_groups["API"].to_port == 4001
      && aws_vpc_security_group_ingress_rule.task_ingress_from_authorized_security_groups["API"].ip_protocol == "tcp"
    )
    error_message = "The service must retain existing targets and admit API ALB traffic only on its application port."
  }
}
