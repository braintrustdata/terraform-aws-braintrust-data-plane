# Mocked providers only: even apply runs create no AWS resources. The managed
# VPC outputs are fixed so subnet lookups can verify both ownership paths.
mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/mock/1111111111111111" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/1111111111111111" }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/net/mock/1111111111111111/2222222222222222" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = { arn = "arn:aws:iam::123456789012:instance-profile/mock" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = { domain_name = "dtest.cloudfront.net" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/mock" }
  }
  mock_resource "aws_appautoscaling_policy" {
    defaults = { arn = "arn:aws:autoscaling:us-east-1:123456789012:scalingPolicy:11111111-1111-1111-1111-111111111111:resource/ecs/service/mock/mock:policyName/mock" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock-bucket" }
  }
  mock_resource "aws_elasticache_cluster" {
    defaults = {
      cache_nodes = [{ id = "0001", address = "redis.example.com", port = 6379, availability_zone = "us-east-1a", outpost_arn = "" }]
    }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:mock" }
  }
  mock_resource "aws_lambda_layer_version" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:layer:mock:1" }
  }
  mock_resource "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:mock-123456" }
  }
  mock_resource "aws_vpc_endpoint" {
    defaults = {
      dns_entry = [{ dns_name = "vpce-quarantine.example.com", hosted_zone_id = "ZTEST" }]
    }
  }
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

override_module {
  target = module.main_vpc[0]
  outputs = {
    vpc_id              = "vpc-11111111111111111"
    private_subnet_1_id = "subnet-11111111111111111"
    private_subnet_2_id = "subnet-22222222222222222"
    private_subnet_3_id = "subnet-33333333333333333"
    public_subnet_1_id  = "subnet-77777777777777777"
  }
}
override_module {
  target = module.quarantine_vpc[0]
  outputs = {
    vpc_id              = "vpc-22222222222222222"
    private_subnet_1_id = "subnet-44444444444444444"
    private_subnet_2_id = "subnet-55555555555555555"
    private_subnet_3_id = "subnet-66666666666666666"
  }
}
override_module {
  target  = module.brainstore_deployment[0]
  outputs = { completion_id = "mock-rollout-complete" }
}
override_data {
  target = data.aws_subnet.quarantine_privatelink_main[0]
  values = { vpc_id = "vpc-11111111111111111", availability_zone = "us-east-1a" }
}
override_data {
  target = data.aws_subnet.quarantine_privatelink_main[1]
  values = { vpc_id = "vpc-11111111111111111", availability_zone = "us-east-1b" }
}
override_data {
  target = data.aws_subnet.quarantine_privatelink_main[2]
  values = { vpc_id = "vpc-11111111111111111", availability_zone = "us-east-1c" }
}
override_data {
  target = data.aws_subnet.quarantine_privatelink_quarantine[0]
  values = { vpc_id = "vpc-22222222222222222", availability_zone = "us-east-1a" }
}
override_data {
  target = data.aws_subnet.quarantine_privatelink_quarantine[1]
  values = { vpc_id = "vpc-22222222222222222", availability_zone = "us-east-1b" }
}
override_data {
  target = data.aws_subnet.quarantine_privatelink_quarantine[2]
  values = { vpc_id = "vpc-22222222222222222", availability_zone = "us-east-1c" }
}

variables {
  braintrust_org_name                  = "test-org"
  primary_org_name                     = "test-org"
  deployment_name                      = "bt-test"
  brainstore_license_key               = "test-license"
  enable_ecs_api                       = true
  enable_quarantine_vpc                = true
  create_ai_gateway                    = true
  enable_ai_gateway                    = true
  use_private_ai_gateway_origin        = true
  use_private_gateway_quarantine_proxy = true
  kms_key_arn                          = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"

  # Ignored on managed paths; reused by runs selecting existing VPCs.
  existing_vpc_id                         = "vpc-11111111111111111"
  existing_private_subnet_1_id            = "subnet-11111111111111111"
  existing_private_subnet_2_id            = "subnet-22222222222222222"
  existing_private_subnet_3_id            = "subnet-33333333333333333"
  existing_public_subnet_1_id             = "subnet-77777777777777777"
  existing_quarantine_private_subnet_1_id = "subnet-44444444444444444"
  existing_quarantine_private_subnet_2_id = "subnet-55555555555555555"
  existing_quarantine_private_subnet_3_id = "subnet-66666666666666666"
}

# Keep module overrides before the first mock apply: Terraform 1.10 crashes
# when replacing a previously instantiated module with an override in test state.
run "rejects_duplicate_main_subnets" {
  command = plan
  variables {
    create_vpc                   = false
    existing_private_subnet_2_id = "subnet-11111111111111111"
    existing_quarantine_vpc_id   = "vpc-22222222222222222"
  }
  # The gateway modules also reject duplicate subnets. Isolate the root
  # PrivateLink validation here; the other runs exercise the real modules.
  override_module {
    target = module.gateway_alb[0]
    outputs = {
      gateway_alb_arn               = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/mock/1111111111111111"
      gateway_alb_security_group_id = "sg-0123456789abcdef0"
      gateway_alb_dns_name          = "gateway.internal"
      gateway_url                   = "http://gateway.internal"
    }
  }
  override_module {
    target = module.gateway_ecs[0]
    outputs = {
      task_security_group_id = "sg-11111111111111111"
      gateway_url            = "http://gateway.internal"
    }
  }
  expect_failures = [data.aws_subnet.quarantine_privatelink_main]
}


run "managed_main_managed_quarantine" {
  command = apply

  assert {
    condition = (
      aws_lb.gateway_quarantine_privatelink[0].internal &&
      aws_lb.gateway_quarantine_privatelink[0].load_balancer_type == "network" &&
      aws_lb_target_group.gateway_quarantine_privatelink_alb[0].target_type == "alb" &&
      aws_lb_target_group.gateway_quarantine_privatelink_alb[0].vpc_id == "vpc-11111111111111111" &&
      aws_vpc_endpoint.quarantine_gateway[0].vpc_id == "vpc-22222222222222222"
    )
    error_message = "PrivateLink must connect the quarantine endpoint to the gateway NLB/ALB in main."
  }
  assert {
    condition = (
      output.quarantine_proxy_url == "http://vpce-quarantine.example.com/v1/proxy" &&
      module.api_ecs[0].quarantine_proxy_url == output.quarantine_proxy_url
    )
    error_message = "API ECS must receive the PrivateLink URL including /v1/proxy."
  }
}

run "unchanged_managed_path_preserves_identity_and_security" {
  command = plan

  assert {
    condition = (
      output.quarantine_gateway_privatelink_endpoint_dns_name == run.managed_main_managed_quarantine.quarantine_gateway_privatelink_endpoint_dns_name
    )
    error_message = "An unchanged managed deployment must keep its endpoint DNS name."
  }
  assert {
    condition = (
      aws_security_group.gateway_quarantine_privatelink_nlb[0].vpc_id == "vpc-11111111111111111" &&
      aws_security_group.quarantine_gateway_privatelink_endpoint[0].vpc_id == "vpc-22222222222222222" &&
      aws_vpc_security_group_ingress_rule.quarantine_gateway_privatelink_endpoint_http[0].referenced_security_group_id == module.services_common.quarantine_lambda_security_group_id &&
      aws_vpc_security_group_ingress_rule.quarantine_gateway_privatelink_endpoint_http[0].security_group_id == aws_security_group.quarantine_gateway_privatelink_endpoint[0].id &&
      aws_vpc_security_group_ingress_rule.quarantine_gateway_privatelink_endpoint_http[0].from_port == 80 &&
      aws_vpc_security_group_ingress_rule.quarantine_gateway_privatelink_endpoint_http[0].to_port == 80 &&
      aws_vpc_security_group_ingress_rule.gateway_alb_from_quarantine_privatelink_nlb[0].referenced_security_group_id == aws_security_group.gateway_quarantine_privatelink_nlb[0].id &&
      aws_vpc_security_group_ingress_rule.gateway_alb_from_quarantine_privatelink_nlb[0].security_group_id == module.gateway_alb[0].gateway_alb_security_group_id &&
      aws_vpc_security_group_egress_rule.gateway_quarantine_privatelink_nlb_to_alb[0].referenced_security_group_id == module.gateway_alb[0].gateway_alb_security_group_id &&
      aws_vpc_security_group_egress_rule.gateway_quarantine_privatelink_nlb_to_alb[0].from_port == 80 &&
      aws_vpc_security_group_egress_rule.gateway_quarantine_privatelink_nlb_to_alb[0].to_port == 80
    )
    error_message = "The path must authorize only quarantine Lambdas into the endpoint and the NLB into the gateway ALB on HTTP."
  }
  assert {
    condition = (
      !aws_vpc_endpoint.quarantine_gateway[0].private_dns_enabled &&
      !aws_vpc_endpoint_service.gateway_quarantine[0].acceptance_required &&
      aws_vpc_endpoint_service_allowed_principal.gateway_quarantine_current_account[0].principal_arn == "arn:aws:iam::123456789012:root" &&
      aws_lb.gateway_quarantine_privatelink[0].enforce_security_group_inbound_rules_on_private_link_traffic == "off" &&
      aws_lb_target_group_attachment.gateway_quarantine_privatelink_alb[0].target_id == module.gateway_alb[0].gateway_alb_arn &&
      aws_lb_listener.gateway_quarantine_privatelink_http[0].port == 80
    )
    error_message = "Preserve same-account access, endpoint DNS, ALB registration, and PrivateLink NLB behavior."
  }
  assert {
    condition = (
      aws_vpc_endpoint.quarantine_gateway[0].tags.BraintrustDeploymentName == "bt-test" &&
      aws_vpc_endpoint.quarantine_gateway[0].tags["aws-apn-id"] == "pc:8ebp76p17b7i08cjqrxaoj0y8" &&
      aws_lb.gateway_quarantine_privatelink[0].tags.BraintrustDeploymentName == "bt-test"
    )
    error_message = "PrivateLink resources must retain deployment and partner tags."
  }
}

run "existing_main_existing_quarantine" {
  command = plan
  variables {
    create_vpc                 = false
    existing_quarantine_vpc_id = "vpc-22222222222222222"
  }
  assert {
    condition = (
      length(module.main_vpc) == 0 && length(module.quarantine_vpc) == 0 &&
      aws_lb_target_group.gateway_quarantine_privatelink_alb[0].vpc_id == "vpc-11111111111111111" &&
      aws_vpc_endpoint.quarantine_gateway[0].vpc_id == "vpc-22222222222222222" &&
      toset(aws_lb.gateway_quarantine_privatelink[0].subnets) == toset(["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]) &&
      toset(aws_vpc_endpoint.quarantine_gateway[0].subnet_ids) == toset(["subnet-44444444444444444", "subnet-55555555555555555", "subnet-66666666666666666"])
    )
    error_message = "VPC ownership must not change PrivateLink placement or take ownership of existing VPCs."
  }
  assert {
    condition = (
      output.quarantine_proxy_url == "http://vpce-quarantine.example.com/v1/proxy" &&
      module.api_ecs[0].quarantine_proxy_url == output.quarantine_proxy_url
    )
    error_message = "Every VPC ownership combination must wire API ECS to the same PrivateLink path."
  }
}

run "existing_main_managed_quarantine" {
  command = plan
  variables {
    create_vpc = false
  }
  assert {
    condition = (
      length(module.main_vpc) == 0 && length(module.quarantine_vpc) == 1 &&
      aws_lb_target_group.gateway_quarantine_privatelink_alb[0].vpc_id == "vpc-11111111111111111" &&
      aws_vpc_endpoint.quarantine_gateway[0].vpc_id == "vpc-22222222222222222" &&
      toset(aws_lb.gateway_quarantine_privatelink[0].subnets) == toset(["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]) &&
      toset(aws_vpc_endpoint.quarantine_gateway[0].subnet_ids) == toset(["subnet-44444444444444444", "subnet-55555555555555555", "subnet-66666666666666666"])
    )
    error_message = "VPC ownership must not change PrivateLink placement or take ownership of existing VPCs."
  }
  assert {
    condition = (
      output.quarantine_proxy_url == "http://vpce-quarantine.example.com/v1/proxy" &&
      module.api_ecs[0].quarantine_proxy_url == output.quarantine_proxy_url
    )
    error_message = "Every VPC ownership combination must wire API ECS to the same PrivateLink path."
  }
}

run "managed_main_existing_quarantine" {
  command = plan
  variables {
    existing_quarantine_vpc_id = "vpc-22222222222222222"
  }
  assert {
    condition = (
      length(module.main_vpc) == 1 && length(module.quarantine_vpc) == 0 &&
      aws_lb_target_group.gateway_quarantine_privatelink_alb[0].vpc_id == "vpc-11111111111111111" &&
      aws_vpc_endpoint.quarantine_gateway[0].vpc_id == "vpc-22222222222222222" &&
      toset(aws_lb.gateway_quarantine_privatelink[0].subnets) == toset(["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]) &&
      toset(aws_vpc_endpoint.quarantine_gateway[0].subnet_ids) == toset(["subnet-44444444444444444", "subnet-55555555555555555", "subnet-66666666666666666"])
    )
    error_message = "VPC ownership must not change PrivateLink placement or take ownership of existing VPCs."
  }
  assert {
    condition = (
      output.quarantine_proxy_url == "http://vpce-quarantine.example.com/v1/proxy" &&
      module.api_ecs[0].quarantine_proxy_url == output.quarantine_proxy_url
    )
    error_message = "Every VPC ownership combination must wire API ECS to the same PrivateLink path."
  }
}

run "existing_vpcs_explicit_override_wins_but_keeps_infrastructure" {
  command = plan
  variables {
    create_vpc                 = false
    existing_quarantine_vpc_id = "vpc-22222222222222222"
    quarantine_proxy_url       = " https://manual.example.com/v1/proxy "
  }
  assert {
    condition = (
      length(aws_vpc_endpoint.quarantine_gateway) == 1 &&
      output.quarantine_proxy_url == "https://manual.example.com/v1/proxy"
    )
    error_message = "An explicit URL must win without changing resource lifetime."
  }
}

run "privatelink_does_not_require_other_gateway_cutover_flags" {
  command = plan
  variables {
    enable_ai_gateway             = false
    use_private_ai_gateway_origin = false
  }
  assert {
    condition     = output.quarantine_proxy_url == "http://vpce-quarantine.example.com/v1/proxy"
    error_message = "Quarantine routing must be independent of API and CloudFront gateway cutover."
  }
}

run "global_gateway_skips_privatelink" {
  command = plan
  variables {
    use_global_ai_gateway_origin  = true
    use_private_ai_gateway_origin = false
  }
  assert {
    condition = (
      length(aws_lb.gateway_quarantine_privatelink) == 0 &&
      length(aws_vpc_endpoint.quarantine_gateway) == 0 &&
      length(data.aws_subnet.quarantine_privatelink_main) == 0 &&
      length(data.aws_subnet.quarantine_privatelink_quarantine) == 0 &&
      output.quarantine_proxy_url == "https://dtest.cloudfront.net/v1/proxy"
    )
    error_message = "Global Gateway must retain its normal URL and skip all PrivateLink provisioning and lookups."
  }
}

run "disabled_quarantine_requires_override" {
  command = plan
  variables { enable_quarantine_vpc = false }
  expect_failures = [terraform_data.quarantine_privatelink_requirements]
}

run "disabled_quarantine_allows_manual_override" {
  command = plan
  variables {
    enable_quarantine_vpc = false
    quarantine_proxy_url  = "https://manual.example.com/v1/proxy"
  }
  assert {
    condition     = length(aws_vpc_endpoint.quarantine_gateway) == 0 && output.quarantine_proxy_url == "https://manual.example.com/v1/proxy"
    error_message = "Preserve the existing manual-URL escape hatch when quarantine is disabled."
  }
}

run "requires_gateway" {
  command = plan
  variables {
    create_ai_gateway             = false
    enable_ai_gateway             = false
    use_private_ai_gateway_origin = false
  }
  expect_failures = [var.use_private_gateway_quarantine_proxy]
}

run "rejects_empty_main_subnet" {
  command = plan
  variables {
    create_vpc                   = false
    existing_private_subnet_1_id = "   "
    existing_quarantine_vpc_id   = "vpc-22222222222222222"
  }
  expect_failures = [data.aws_subnet.quarantine_privatelink_main]
}


run "rejects_empty_quarantine_subnet" {
  command = plan
  variables {
    create_vpc                              = false
    existing_quarantine_vpc_id              = "vpc-22222222222222222"
    existing_quarantine_private_subnet_1_id = ""
  }
  expect_failures = [data.aws_subnet.quarantine_privatelink_quarantine]
}

run "rejects_duplicate_quarantine_subnets" {
  command = plan
  variables {
    create_vpc                              = false
    existing_quarantine_vpc_id              = "vpc-22222222222222222"
    existing_quarantine_private_subnet_2_id = "subnet-44444444444444444"
  }
  expect_failures = [data.aws_subnet.quarantine_privatelink_quarantine]
}

run "rejects_empty_main_vpc" {
  command = plan
  variables {
    create_vpc                 = false
    existing_vpc_id            = ""
    existing_quarantine_vpc_id = "vpc-22222222222222222"
  }
  expect_failures = [data.aws_subnet.quarantine_privatelink_main]
}

run "rejects_empty_quarantine_vpc" {
  command = plan
  variables {
    create_vpc                 = false
    existing_quarantine_vpc_id = " "
  }
  expect_failures = [data.aws_subnet.quarantine_privatelink_quarantine]
}

run "rejects_missing_main_subnet" {
  command = plan
  variables {
    create_vpc                   = false
    existing_private_subnet_3_id = null
    existing_quarantine_vpc_id   = "vpc-22222222222222222"
  }
  expect_failures = [var.existing_private_subnet_3_id]
}

run "rejects_missing_quarantine_subnet" {
  command = plan
  variables {
    create_vpc                              = false
    existing_quarantine_vpc_id              = "vpc-22222222222222222"
    existing_quarantine_private_subnet_3_id = null
  }
  expect_failures = [var.existing_quarantine_private_subnet_3_id]
}

run "rejects_main_subnet_wrong_vpc" {
  command = plan
  variables {
    create_vpc                 = false
    existing_quarantine_vpc_id = "vpc-22222222222222222"
  }
  override_data {
    target = data.aws_subnet.quarantine_privatelink_main[0]
    values = { vpc_id = "vpc-99999999999999999", availability_zone = "us-east-1a" }
  }
  expect_failures = [data.aws_subnet.quarantine_privatelink_main]
}

run "rejects_quarantine_subnet_wrong_vpc" {
  command = plan
  variables {
    create_vpc                 = false
    existing_quarantine_vpc_id = "vpc-22222222222222222"
  }
  override_data {
    target = data.aws_subnet.quarantine_privatelink_quarantine[0]
    values = { vpc_id = "vpc-99999999999999999", availability_zone = "us-east-1a" }
  }
  expect_failures = [data.aws_subnet.quarantine_privatelink_quarantine]
}

run "rejects_duplicate_main_az" {
  command = plan
  variables {
    create_vpc                 = false
    existing_quarantine_vpc_id = "vpc-22222222222222222"
  }
  override_data {
    target = data.aws_subnet.quarantine_privatelink_main[2]
    values = { vpc_id = "vpc-11111111111111111", availability_zone = "us-east-1a" }
  }
  expect_failures = [terraform_data.quarantine_privatelink_requirements]
}

run "rejects_duplicate_quarantine_az" {
  command = plan
  variables {
    create_vpc                 = false
    existing_quarantine_vpc_id = "vpc-22222222222222222"
  }
  override_data {
    target = data.aws_subnet.quarantine_privatelink_quarantine[2]
    values = { vpc_id = "vpc-22222222222222222", availability_zone = "us-east-1a" }
  }
  expect_failures = [terraform_data.quarantine_privatelink_requirements]
}

run "rejects_endpoint_az_not_served_by_nlb" {
  command = plan
  variables {
    create_vpc                 = false
    existing_quarantine_vpc_id = "vpc-22222222222222222"
  }
  override_data {
    target = data.aws_subnet.quarantine_privatelink_quarantine[2]
    values = { vpc_id = "vpc-22222222222222222", availability_zone = "us-east-1d" }
  }
  expect_failures = [terraform_data.quarantine_privatelink_requirements]
}

run "private_automatic_rejects_duplicate_main_az" {
  command = plan
  variables {
    enable_private_dataplane             = true
    use_private_gateway_quarantine_proxy = false
    braintrust_api_alb_custom_domain     = "api.example.internal"
    braintrust_api_alb_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    create_vpc                           = false
    existing_quarantine_vpc_id           = "vpc-22222222222222222"
  }
  override_data {
    target = data.aws_subnet.quarantine_privatelink_main[2]
    values = { vpc_id = "vpc-11111111111111111", availability_zone = "us-east-1a" }
  }
  expect_failures = [terraform_data.quarantine_privatelink_requirements]
}

run "private_automatic_rejects_duplicate_quarantine_az" {
  command = plan
  variables {
    enable_private_dataplane             = true
    use_private_gateway_quarantine_proxy = false
    braintrust_api_alb_custom_domain     = "api.example.internal"
    braintrust_api_alb_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    create_vpc                           = false
    existing_quarantine_vpc_id           = "vpc-22222222222222222"
  }
  override_data {
    target = data.aws_subnet.quarantine_privatelink_quarantine[2]
    values = { vpc_id = "vpc-22222222222222222", availability_zone = "us-east-1a" }
  }
  expect_failures = [terraform_data.quarantine_privatelink_requirements]
}

run "private_automatic_rejects_endpoint_az_not_served_by_nlb" {
  command = plan
  variables {
    enable_private_dataplane             = true
    use_private_gateway_quarantine_proxy = false
    braintrust_api_alb_custom_domain     = "api.example.internal"
    braintrust_api_alb_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    create_vpc                           = false
    existing_quarantine_vpc_id           = "vpc-22222222222222222"
  }
  override_data {
    target = data.aws_subnet.quarantine_privatelink_quarantine[2]
    values = { vpc_id = "vpc-22222222222222222", availability_zone = "us-east-1d" }
  }
  expect_failures = [terraform_data.quarantine_privatelink_requirements]
}

run "disabled_existing_vpcs_leave_no_privatelink_resources" {
  command = plan
  variables {
    create_vpc                           = false
    existing_quarantine_vpc_id           = "vpc-22222222222222222"
    use_private_gateway_quarantine_proxy = false
  }
  assert {
    condition = (
      length(aws_lb.gateway_quarantine_privatelink) == 0 &&
      length(aws_vpc_endpoint.quarantine_gateway) == 0 &&
      length(aws_vpc_endpoint_service.gateway_quarantine) == 0 &&
      length(aws_security_group.gateway_quarantine_privatelink_nlb) == 0 &&
      length(aws_security_group.quarantine_gateway_privatelink_endpoint) == 0 &&
      length(data.aws_subnet.quarantine_privatelink_main) == 0 &&
      length(data.aws_subnet.quarantine_privatelink_quarantine) == 0 &&
      output.quarantine_proxy_url == "https://dtest.cloudfront.net/v1/proxy"
    )
    error_message = "Opt-out must restore the normal URL and remove the entire PrivateLink path and lookups."
  }
}

run "external_eks_rejects_terraform_privatelink" {
  command = plan
  variables {
    use_deployment_mode_external_eks = true
    enable_ecs_api                   = false
  }
  expect_failures = [var.use_private_gateway_quarantine_proxy]
}

run "disable_after_enable" {
  command = apply
  variables {
    use_private_gateway_quarantine_proxy = false
  }
  assert {
    condition = (
      length(aws_vpc_endpoint.quarantine_gateway) == 0 &&
      output.quarantine_gateway_privatelink_service_name == null &&
      output.quarantine_gateway_privatelink_endpoint_dns_name == null &&
      output.quarantine_proxy_url == "https://dtest.cloudfront.net/v1/proxy"
    )
    error_message = "Disabling must remove the path and restore the ECS-mode CloudFront fallback."
  }
}

# Mock applies resolve endpoint URLs after private mode changes resource dependencies.
run "private_existing_main_existing_quarantine" {
  command = apply
  variables {
    enable_private_dataplane             = true
    use_private_gateway_quarantine_proxy = false
    braintrust_api_alb_custom_domain     = "api.example.internal"
    braintrust_api_alb_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    create_vpc                           = false
    existing_quarantine_vpc_id           = "vpc-22222222222222222"
  }
  assert {
    condition = (
      length(module.main_vpc) == 0 && length(module.quarantine_vpc) == 0 &&
      aws_lb_target_group.gateway_quarantine_privatelink_alb[0].vpc_id == "vpc-11111111111111111" &&
      aws_vpc_endpoint.quarantine_gateway[0].vpc_id == "vpc-22222222222222222" &&
      toset(aws_lb.gateway_quarantine_privatelink[0].subnets) == toset(["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]) &&
      toset(aws_vpc_endpoint.quarantine_gateway[0].subnet_ids) == toset(["subnet-44444444444444444", "subnet-55555555555555555", "subnet-66666666666666666"])
    )
    error_message = "VPC ownership must not change PrivateLink placement or take ownership of existing VPCs."
  }
  assert {
    condition = (
      output.quarantine_proxy_url == "http://vpce-quarantine.example.com/v1/proxy" &&
      module.api_ecs[0].quarantine_proxy_url == output.quarantine_proxy_url
    )
    error_message = "Every VPC ownership combination must wire API ECS to the same PrivateLink path."
  }

  assert {
    condition = (
      length(module.ingress) == 0 && local.enable_ai_gateway &&
      output.api_url == "https://api.example.internal" &&
      module.api_ecs[0].internal_url != null
    )
    error_message = "Private mode must retain internal API callbacks and the gateway without CloudFront."
  }
}

run "private_existing_main_managed_quarantine" {
  command = apply
  variables {
    enable_private_dataplane             = true
    use_private_gateway_quarantine_proxy = false
    braintrust_api_alb_custom_domain     = "api.example.internal"
    braintrust_api_alb_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    create_vpc                           = false
  }
  assert {
    condition = (
      length(module.main_vpc) == 0 && length(module.quarantine_vpc) == 1 &&
      aws_lb_target_group.gateway_quarantine_privatelink_alb[0].vpc_id == "vpc-11111111111111111" &&
      aws_vpc_endpoint.quarantine_gateway[0].vpc_id == "vpc-22222222222222222" &&
      toset(aws_lb.gateway_quarantine_privatelink[0].subnets) == toset(["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]) &&
      toset(aws_vpc_endpoint.quarantine_gateway[0].subnet_ids) == toset(["subnet-44444444444444444", "subnet-55555555555555555", "subnet-66666666666666666"])
    )
    error_message = "VPC ownership must not change PrivateLink placement or take ownership of existing VPCs."
  }
  assert {
    condition = (
      output.quarantine_proxy_url == "http://vpce-quarantine.example.com/v1/proxy" &&
      module.api_ecs[0].quarantine_proxy_url == output.quarantine_proxy_url
    )
    error_message = "Every VPC ownership combination must wire API ECS to the same PrivateLink path."
  }

  assert {
    condition = (
      length(module.ingress) == 0 && local.enable_ai_gateway &&
      output.api_url == "https://api.example.internal" &&
      module.api_ecs[0].internal_url != null
    )
    error_message = "Private mode must retain internal API callbacks and the gateway without CloudFront."
  }
}

run "private_managed_main_existing_quarantine" {
  command = apply
  variables {
    enable_private_dataplane             = true
    use_private_gateway_quarantine_proxy = false
    braintrust_api_alb_custom_domain     = "api.example.internal"
    braintrust_api_alb_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    existing_quarantine_vpc_id           = "vpc-22222222222222222"
  }
  assert {
    condition = (
      length(module.main_vpc) == 1 && length(module.quarantine_vpc) == 0 &&
      aws_lb_target_group.gateway_quarantine_privatelink_alb[0].vpc_id == "vpc-11111111111111111" &&
      aws_vpc_endpoint.quarantine_gateway[0].vpc_id == "vpc-22222222222222222" &&
      toset(aws_lb.gateway_quarantine_privatelink[0].subnets) == toset(["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]) &&
      toset(aws_vpc_endpoint.quarantine_gateway[0].subnet_ids) == toset(["subnet-44444444444444444", "subnet-55555555555555555", "subnet-66666666666666666"])
    )
    error_message = "VPC ownership must not change PrivateLink placement or take ownership of existing VPCs."
  }
  assert {
    condition = (
      output.quarantine_proxy_url == "http://vpce-quarantine.example.com/v1/proxy" &&
      module.api_ecs[0].quarantine_proxy_url == output.quarantine_proxy_url
    )
    error_message = "Every VPC ownership combination must wire API ECS to the same PrivateLink path."
  }

  assert {
    condition = (
      length(module.ingress) == 0 && local.enable_ai_gateway &&
      output.api_url == "https://api.example.internal" &&
      module.api_ecs[0].internal_url != null
    )
    error_message = "Private mode must retain internal API callbacks and the gateway without CloudFront."
  }
}

run "private_existing_main_without_quarantine" {
  command = apply
  variables {
    enable_private_dataplane             = true
    create_vpc                           = false
    enable_quarantine_vpc                = false
    use_private_gateway_quarantine_proxy = false
    braintrust_api_alb_custom_domain     = "api.example.internal"
    braintrust_api_alb_certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
  }
  assert {
    condition = (
      length(module.main_vpc) == 0 && length(module.quarantine_vpc) == 0 &&
      length(aws_vpc_endpoint.quarantine_gateway) == 0 &&
      length(module.ingress) == 0 && length(module.gateway_ecs) == 1
    )
    error_message = "An existing main VPC must support private mode without quarantine or CloudFront."
  }
}
