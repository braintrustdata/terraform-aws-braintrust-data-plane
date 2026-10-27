mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/1111111111111111"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/api/1111111111111111/2222222222222222"
    }
  }
}

variables {
  deployment_name                       = "bt-test"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id                                = "vpc-0123456789abcdef0"
  private_subnet_ids                    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  ecs_cluster_arn                       = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                      = "bt-test"
  braintrust_org_name                   = "test-org"
  database_url_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  brainstore_hostname                   = "brainstore.example.internal"
  brainstore_port                       = 9000
  response_bucket                       = "bt-test-responses"
  code_bundle_bucket                    = "bt-test-code"
  function_tools_secret_arn             = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  whitelisted_origins                   = ["https://example.com"]
  outbound_rate_limit_window_minutes    = 1
  outbound_rate_limit_max_requests      = 100
  monitoring_telemetry                  = "true"
  disable_billing_telemetry_aggregation = false
  billing_telemetry_log_level           = "info"
  quarantine_proxy_url                  = ""
  task_role_arn                         = "arn:aws:iam::123456789012:role/api-task"
  task_security_group_id                = "sg-0123456789abcdef0"

  braintrust_api_cpu_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_event_loop_utilization_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
  }
  braintrust_api_ingest_cpu_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_ingest_event_loop_utilization_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_ingest_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
  }
  braintrust_api_background_cpu_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_background_event_loop_utilization_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_background_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
  }
}

run "private_api_listener_and_admission" {
  command = plan

  module {
    source = "./modules/api-ecs"
  }

  variables {
    enable_private_dataplane = true
    alb_custom_domain        = "api.example.internal"
    alb_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    authorized_cidr_blocks   = ["10.20.0.0/16"]
    internal_authorized_security_groups = {
      brainstore = "sg-11111111111111111"
    }
    gateway_security_groups = {
      gateway = "sg-22222222222222222"
    }
    loop_runtime_security_groups = {
      loop_runtime = "sg-33333333333333333"
    }
  }

  assert {
    condition     = aws_lb.api_ecs.internal && aws_lb_listener.api_ecs_http.port == 443 && aws_lb_listener.api_ecs_http.protocol == "HTTPS"
    error_message = "The customer listener must serve HTTPS on an internal ALB."
  }

  assert {
    condition     = length(aws_lb_listener.api_ecs_internal) == 1 && aws_lb_listener.api_ecs_internal[0].port == 8000 && aws_lb_listener.api_ecs_internal[0].protocol == "HTTP"
    error_message = "Private mode must create the internal HTTP callback listener on port 8000."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_ingress_http_from_cloudfront) == 0 && length(data.aws_ec2_managed_prefix_list.cloudfront_origin_facing) == 0
    error_message = "Private mode must omit CloudFront admission and its prefix list lookup."
  }

  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.alb_ingress_http_from_internal_security_groups)) == toset(["brainstore"]) && alltrue([for rule in aws_vpc_security_group_ingress_rule.alb_ingress_http_from_internal_security_groups : rule.from_port == 8000 && rule.to_port == 8000 && rule.ip_protocol == "tcp" && rule.cidr_ipv4 == null && rule.cidr_ipv6 == null])
    error_message = "Internal callback access must use only the supplied service security groups on TCP port 8000."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_ingress_from_gateway["gateway"].from_port == 8000 && aws_vpc_security_group_ingress_rule.alb_ingress_from_gateway["gateway"].to_port == 8000 && aws_vpc_security_group_ingress_rule.alb_ingress_from_gateway["gateway"].referenced_security_group_id == "sg-22222222222222222"
    error_message = "Gateway callbacks must use the existing gateway rule on internal HTTP port 8000."
  }

  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.alb_ingress_http_from_loop_runtime)) == toset(["loop_runtime"]) && alltrue([for rule in aws_vpc_security_group_ingress_rule.alb_ingress_http_from_loop_runtime : rule.from_port == 8000 && rule.to_port == 8000 && rule.ip_protocol == "tcp" && rule.cidr_ipv4 == null && rule.cidr_ipv6 == null && rule.referenced_security_group_id == "sg-33333333333333333"])
    error_message = "Loop callback access must use only its service security group on TCP port 8000."
  }

  assert {
    condition     = alltrue([for rule in aws_security_group_rule.alb_ingress_http_from_authorized_cidr_blocks : rule.from_port == 443 && rule.to_port == 443])
    error_message = "Customer CIDR access must apply only to the HTTPS listener."
  }

  assert {
    condition     = toset(keys(aws_lb_listener_rule.alb_internal_path_routes)) == toset(keys(aws_lb_listener_rule.alb_path_routes)) && alltrue([for key, rule in aws_lb_listener_rule.alb_internal_path_routes : rule.priority == aws_lb_listener_rule.alb_path_routes[key].priority && rule.condition == aws_lb_listener_rule.alb_path_routes[key].condition])
    error_message = "Internal callbacks must preserve every customer listener route and request condition."
  }

  assert {
    condition     = output.http_url == "https://api.example.internal"
    error_message = "The customer URL must retain the HTTPS hostname."
  }
}

run "public_api_has_no_private_callback_listener" {
  command = plan

  module {
    source = "./modules/api-ecs"
  }

  assert {
    condition     = length(aws_lb_target_group.private_gateway) == 0 && length(aws_lb_target_group.private_loop_runtime) == 0 && length(aws_lb_listener_rule.private_gateway) == 0 && length(aws_lb_listener_rule.private_loop_runtime) == 0 && length(aws_lb_listener.api_ecs_internal) == 0 && length(aws_lb_listener_rule.alb_internal_path_routes) == 0 && length(aws_vpc_security_group_ingress_rule.alb_ingress_http_from_internal_security_groups) == 0 && length(aws_vpc_security_group_ingress_rule.alb_ingress_http_from_loop_runtime) == 0
    error_message = "The default mode must omit private callback resources."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_ingress_http_from_cloudfront) == 1 && output.internal_url == null
    error_message = "The default mode must retain CloudFront admission and omit the private callback URL."
  }

  assert {
    condition = (
      contains(keys(aws_lb_listener_rule.alb_path_routes), "ANY:/v1/proxy/chat/completions")
      && contains(keys(aws_lb_listener_rule.alb_path_routes), "ANY:/v1/proxy/responses")
      && length(aws_lb_listener_rule.private_internal_gateway) == 0
      && length(aws_lb_listener_rule.private_internal_loop_runtime) == 0
    )
    error_message = "Public mode must retain the background API proxy routes and omit internal service routes."
  }
}

run "private_ssm_url_uses_aws_dns_without_customer_dns" {
  command = apply

  plan_options {
    target = [aws_ssm_parameter.api_url, aws_lb_listener.api_ecs_http, aws_vpc_security_group_ingress_rule.alb_ingress_from_gateway]
  }

  module {
    source = "./modules/api-ecs"
  }

  variables {
    enable_private_dataplane = true
    alb_custom_domain        = "api.example.internal"
    alb_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    internal_authorized_security_groups = {
      brainstore = "sg-11111111111111111"
    }
  }

  override_resource {
    target = aws_lb.api_ecs
    values = {
      dns_name = "internal-api.us-east-1.elb.amazonaws.com"
      arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/api/1111111111111111"
    }
  }

  assert {
    condition     = output.internal_url == "http://internal-api.us-east-1.elb.amazonaws.com:8000" && aws_ssm_parameter.api_url.value == "http://internal-api.us-east-1.elb.amazonaws.com:8000"
    error_message = "Brainstore and callback URLs must use AWS DNS and HTTP without customer DNS or certificate trust."
  }

  assert {
    condition     = output.http_url == "https://api.example.internal"
    error_message = "The customer URL must remain HTTPS when callbacks use the internal HTTP listener."
  }
}

run "private_listeners_bypass_api_proxies" {
  command = apply

  plan_options {
    target = [aws_lb_listener_rule.private_gateway, aws_lb_listener_rule.private_loop_runtime, aws_lb_listener_rule.private_internal_gateway, aws_lb_listener_rule.private_internal_loop_runtime, aws_lb_listener_rule.alb_path_routes, aws_lb_listener_rule.alb_internal_path_routes]
  }

  module {
    source = "./modules/api-ecs"
  }

  variables {
    enable_private_dataplane = true
    enable_loop_runtime      = true
  }

  override_resource {
    target = aws_lb_target_group.private_gateway[0]
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/2222222222222222"
    }
  }

  override_resource {
    target = aws_lb_target_group.private_loop_runtime[0]
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/loop/3333333333333333"
    }
  }

  assert {
    condition = (
      one(aws_lb_listener_rule.private_gateway[0].condition).path_pattern[0].values == toset(["/v1/proxy", "/v1/proxy/*"])
      && aws_lb_listener_rule.private_gateway[0].action[0].target_group_arn == aws_lb_target_group.private_gateway[0].arn
      && alltrue([for rule in aws_lb_listener_rule.alb_path_routes : aws_lb_listener_rule.private_gateway[0].priority < rule.priority])
    )
    error_message = "All gateway paths must bypass API targets."
  }

  assert {
    condition = (
      one(aws_lb_listener_rule.private_loop_runtime[0].condition).path_pattern[0].values == toset(["/loop/runtime", "/loop/runtime/*"])
      && aws_lb_listener_rule.private_loop_runtime[0].action[0].target_group_arn == aws_lb_target_group.private_loop_runtime[0].arn
      && alltrue([for rule in aws_lb_listener_rule.alb_path_routes : aws_lb_listener_rule.private_loop_runtime[0].priority < rule.priority])
    )
    error_message = "All Loop paths must bypass API targets without a method condition."
  }

  assert {
    condition = (
      aws_lb_target_group.private_gateway[0].port == 8080
      && aws_lb_target_group.private_gateway[0].target_type == "ip"
      && aws_lb_target_group.private_gateway[0].health_check[0].path == "/health"
      && aws_lb_target_group.private_loop_runtime[0].port == 4001
      && aws_lb_target_group.private_loop_runtime[0].target_type == "ip"
      && aws_lb_target_group.private_loop_runtime[0].health_check[0].path == "/health/liveness"
      && length(aws_lb_listener_rule.private_gateway[0].condition) == 1
      && length(aws_lb_listener_rule.private_loop_runtime[0].condition) == 1
    )
    error_message = "Direct routes must use task ports, service health paths, and path conditions only."
  }

  assert {
    condition = (
      aws_lb_listener_rule.private_internal_gateway[0].condition == aws_lb_listener_rule.private_gateway[0].condition
      && aws_lb_listener_rule.private_internal_gateway[0].action == aws_lb_listener_rule.private_gateway[0].action
      && aws_lb_listener_rule.private_internal_gateway[0].priority == aws_lb_listener_rule.private_gateway[0].priority
      && aws_lb_listener_rule.private_internal_loop_runtime[0].condition == aws_lb_listener_rule.private_loop_runtime[0].condition
      && aws_lb_listener_rule.private_internal_loop_runtime[0].action == aws_lb_listener_rule.private_loop_runtime[0].action
      && aws_lb_listener_rule.private_internal_loop_runtime[0].priority == aws_lb_listener_rule.private_loop_runtime[0].priority
      && aws_lb_listener_rule.private_internal_gateway[0].listener_arn == aws_lb_listener.api_ecs_internal[0].arn
      && aws_lb_listener_rule.private_internal_loop_runtime[0].listener_arn == aws_lb_listener.api_ecs_internal[0].arn
    )
    error_message = "Both private listeners must route gateway and Loop requests directly to the same service targets."
  }

  assert {
    condition = alltrue([
      for rules in [aws_lb_listener_rule.alb_path_routes, aws_lb_listener_rule.alb_internal_path_routes] :
      !contains(keys(rules), "ANY:/v1/proxy/chat/completions") && !contains(keys(rules), "ANY:/v1/proxy/responses")
    ])
    error_message = "Private listeners must omit redundant proxy routes to the background API."
  }
}

run "private_mode_without_loop_omits_loop_targets" {
  command = plan

  module {
    source = "./modules/api-ecs"
  }

  variables {
    enable_private_dataplane = true
    enable_loop_runtime      = false
  }

  assert {
    condition = (
      length(aws_lb_target_group.private_gateway) == 1
      && length(aws_lb_listener_rule.private_gateway) == 1
      && length(aws_lb_target_group.private_loop_runtime) == 0
      && length(aws_lb_listener_rule.private_loop_runtime) == 0
      && length(aws_lb_listener_rule.private_internal_loop_runtime) == 0
      && length(aws_lb_listener_rule.private_internal_gateway) == 1
    )
    error_message = "Private mode must retain gateway routes and omit disabled Loop resources."
  }
}
