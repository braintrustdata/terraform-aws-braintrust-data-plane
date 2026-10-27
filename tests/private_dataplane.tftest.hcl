mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name                = "test-org"
  primary_org_name                   = "test-org"
  deployment_name                    = "bt-test"
  brainstore_license_key             = "test-license"
  enable_private_dataplane           = true
  enable_ecs_api                     = true
  create_ai_gateway                  = true
  enable_ai_gateway                  = true
  enable_quarantine_vpc              = true
  use_private_ai_gateway_origin      = false
  braintrust_api_alb_custom_domain   = "api.example.internal"
  braintrust_api_alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
}

run "private_dataplane_preserves_services_without_cloudfront" {
  command = plan

  assert {
    condition     = length(module.ingress) == 0 && length(module.api_ecs) == 1 && length(module.gateway_ecs) == 1
    error_message = "Private mode must omit CloudFront and retain API ECS and the private gateway."
  }

  assert {
    condition     = output.api_url == "https://api.example.internal"
    error_message = "The customer API URL must use the customer HTTPS hostname."
  }

  assert {
    condition     = output.cloudfront_distribution_domain_name == null && output.cloudfront_distribution_arn == null && output.cloudfront_distribution_hosted_zone_id == null
    error_message = "Private mode must return null CloudFront outputs."
  }

  assert {
    condition     = local.wire_quarantine_to_private_gateway && local.create_quarantine_gateway_privatelink && length(aws_vpc_endpoint.quarantine_gateway) == 1
    error_message = "Private mode must create quarantine PrivateLink without a separate opt-in flag."
  }

  assert {
    condition     = length(module.services) == 1 && module.services[0].api_handler_arn == null && module.services[0].ai_proxy_arn == null
    error_message = "Private mode must retain the services module and omit only the existing ECS replacements."
  }

  assert {
    condition     = alltrue([for name in ["billing-cron", "automation-cron", "catchup-etl"] : contains(keys(module.services[0].monitoring_functions), name)])
    error_message = "Private mode must retain the cron and CatchupETL Lambdas."
  }
}

run "private_dataplane_with_loop" {
  command = plan

  variables {
    enable_loop_runtime = true
  }

  assert {
    condition     = length(module.loop_runtime_ecs) == 1 && length(module.loop_runtime_alb) == 1 && length(module.ingress) == 0
    error_message = "Private mode must retain Loop without a CloudFront route."
  }
}

run "private_dataplane_without_quarantine" {
  command = plan

  variables {
    enable_quarantine_vpc = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.quarantine_gateway) == 0 && length(module.gateway_ecs) == 1
    error_message = "Private mode without quarantine must retain the private gateway without a quarantine endpoint."
  }
}

run "private_callbacks_use_internal_api_and_gateway_urls" {
  command = plan

  variables {
    enable_loop_runtime = true
  }

  override_module {
    target = module.api_ecs[0]
    outputs = {
      alb_security_group_id                 = "sg-44444444444444444"
      private_gateway_target_group_arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/customer-gateway/4444444444444444"
      private_loop_runtime_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/customer-loop/5555555555555555"
      internal_url                          = "http://internal-api.us-east-1.elb.amazonaws.com:8000"
      http_url                              = "https://api.example.internal"
      url_ssm_parameter_version             = 1
      monitoring_targets                    = {}
      cloudwatch_log_groups                 = {}
    }
  }

  override_module {
    target = module.gateway_alb[0]
    outputs = {
      gateway_url                   = "http://internal-gateway.us-east-1.elb.amazonaws.com"
      gateway_alb_security_group_id = "sg-11111111111111111"
      gateway_alb_arn               = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/gateway/1111111111111111"
      gateway_target_group_arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/1111111111111111"
      gateway_http_listener_arn     = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1111111111111111/2222222222222222"
    }
  }

  assert {
    condition     = local.internal_api_url == "http://internal-api.us-east-1.elb.amazonaws.com:8000" && output.api_url == "https://api.example.internal"
    error_message = "Internal callbacks must use AWS DNS independently of the customer HTTPS URL."
  }

  assert {
    condition     = local.loop_runtime_ai_proxy_url == "http://internal-gateway.us-east-1.elb.amazonaws.com/v1/proxy"
    error_message = "Loop must use the private gateway instead of a hosted gateway or CloudFront."
  }
}

run "rejects_private_mode_without_ecs_api" {
  command = plan
  variables {
    enable_ecs_api = false
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_without_gateway_infrastructure" {
  command = plan
  variables {
    create_ai_gateway = false
    enable_ai_gateway = false
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_without_gateway_activation" {
  command = plan
  variables {
    enable_ai_gateway = false
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_without_customer_hostname" {
  command = plan
  variables {
    braintrust_api_alb_custom_domain = null
  }
  expect_failures = [var.braintrust_api_alb_custom_domain]
}

run "rejects_private_mode_without_customer_certificate" {
  command = plan
  variables {
    braintrust_api_alb_certificate_arn = null
  }
  expect_failures = [var.braintrust_api_alb_custom_domain]
}

run "rejects_private_mode_with_hosted_proxy" {
  command = plan
  variables {
    use_global_ai_proxy = true
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_with_hosted_gateway_origin" {
  command = plan
  variables {
    use_global_ai_gateway_origin = true
  }
  expect_failures = [var.enable_private_dataplane]
}

run "private_mode_ignores_default_cloudfront_private_gateway_origin" {
  command = plan
  variables {
    use_private_ai_gateway_origin = true
  }
  assert {
    condition     = length(module.ingress) == 0 && !local.enable_private_ai_gateway_origin
    error_message = "Private mode must ignore the default CloudFront gateway origin flag."
  }
}

run "rejects_private_mode_with_quarantine_proxy_override" {
  command = plan
  variables {
    quarantine_proxy_url = "https://proxy.example.com/v1/proxy"
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_with_existing_main_vpc" {
  command = plan
  variables {
    create_vpc                   = false
    existing_vpc_id              = "vpc-12345678"
    existing_private_subnet_1_id = "subnet-11111111"
    existing_private_subnet_2_id = "subnet-22222222"
    existing_private_subnet_3_id = "subnet-33333333"
    existing_public_subnet_1_id  = "subnet-44444444"
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_with_existing_quarantine_vpc" {
  command = plan
  variables {
    existing_quarantine_vpc_id              = "vpc-12345678"
    existing_quarantine_private_subnet_1_id = "subnet-11111111"
    existing_quarantine_private_subnet_2_id = "subnet-22222222"
    existing_quarantine_private_subnet_3_id = "subnet-33333333"
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_with_external_eks" {
  command = plan
  variables {
    use_deployment_mode_external_eks = true
    enable_ecs_api                   = false
    braintrust_api_url               = "https://external-api.example.internal"
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_with_cloudfront_domain" {
  command = plan
  variables {
    custom_domain = "public.example.com"
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_with_cloudfront_waf" {
  command = plan
  variables {
    waf_acl_id = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/test/11111111-1111-1111-1111-111111111111"
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_with_cloudfront_certificate" {
  command = plan
  variables {
    custom_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/22222222-2222-2222-2222-222222222222"
  }
  expect_failures = [var.enable_private_dataplane]
}

run "rejects_private_mode_without_customer_tls" {
  command = plan
  variables {
    braintrust_api_alb_custom_domain   = null
    braintrust_api_alb_certificate_arn = null
  }
  expect_failures = [var.enable_private_dataplane]
}
