mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = {
        ImageArn            = "arn:aws:lambda:us-east-1:123456789012:microvm-image:bt-loop-bt-test"
        ImageVersion        = "1"
        NetworkConnectorArn = "arn:aws:lambda:us-east-1:123456789012:network-connector:bt-loop-bt-test-restricted-egress"
      }
    }
  }
  mock_resource "aws_vpc_endpoint" {
    defaults = {
      dns_entry = [
        {
          dns_name       = "vpce-0123456789abcdef0-abcdefgh.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com"
          hosted_zone_id = "Z7HUB22UULQXV"
        },
      ]
    }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-test-loop-egress/1111111111111111" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222" }
  }
}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  deployment_name           = "bt-test"
  microvm_version_tag       = "test"
  endpoint_vpc_id           = "vpc-11111111111111111"
  endpoint_subnet_ids       = ["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]
  runtime_security_group_id = "sg-11111111111111111"
}

override_data {
  target = data.aws_subnet.egress_gateway_nlb[0]
  values = { availability_zone = "us-east-1a" }
}

override_data {
  target = data.aws_subnet.egress_gateway_nlb[1]
  values = { availability_zone = "us-east-1b" }
}

override_data {
  target = data.aws_subnet.egress_gateway_nlb[2]
  values = { availability_zone = "us-east-1c" }
}

override_data {
  target = data.aws_subnet.restricted_egress_existing[0]
  values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1a" }
}

override_data {
  target = data.aws_subnet.restricted_egress_existing[1]
  values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1b" }
}

override_data {
  target = data.aws_subnet.restricted_egress_existing[2]
  values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1c" }
}

# Seed the subnet addresses, AZs, and CIDRs used by v6.8.1 before planning the
# gateway with main VPC zones that differ from those original connector zones.
run "legacy_connector_subnet_state" {
  command = apply
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  plan_options {
    target = [aws_subnet.restricted_egress, aws_route_table_association.restricted_egress]
  }
}

run "managed_isolation_by_default" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }

  override_data {
    target = data.aws_subnet.egress_gateway_nlb[0]
    values = { availability_zone = "us-east-1d" }
  }

  override_data {
    target = data.aws_subnet.egress_gateway_nlb[1]
    values = { availability_zone = "us-east-1e" }
  }

  override_data {
    target = data.aws_subnet.egress_gateway_nlb[2]
    values = { availability_zone = "us-east-1d" }
  }

  assert {
    condition     = aws_vpc_endpoint.loop_runtime_microvm.private_dns_enabled && aws_vpc_endpoint.loop_runtime_microvm.service_name == "com.amazonaws.us-east-1.lambda-microvm" && aws_vpc_endpoint.loop_runtime_microvm.vpc_id == var.endpoint_vpc_id
    error_message = "The MicroVM endpoint must use private DNS in the main VPC."
  }
  assert {
    condition     = jsondecode(aws_vpc_endpoint.loop_runtime_microvm.policy).Statement[0].Condition.StringEquals["aws:ResourceAccount"] == "123456789012"
    error_message = "The MicroVM endpoint must restrict connections to this account."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.loop_runtime_microvm_https.from_port == 443 && aws_vpc_security_group_ingress_rule.loop_runtime_microvm_https.to_port == 443 && aws_vpc_security_group_ingress_rule.loop_runtime_microvm_https.referenced_security_group_id == var.runtime_security_group_id
    error_message = "Only the runtime security group must receive HTTPS access to the endpoint."
  }
  assert {
    condition     = length(aws_vpc.restricted_egress) == 1 && length(aws_subnet.restricted_egress) == 3 && length(aws_subnet.egress_gateway) == 3
    error_message = "The managed VPC must have three connector subnets and three endpoint subnets."
  }
  assert {
    condition     = aws_subnet.restricted_egress[*].availability_zone == ["us-east-1a", "us-east-1b", "us-east-1c"] && aws_subnet.restricted_egress[*].cidr_block == ["10.255.1.0/24", "10.255.2.0/24", "10.255.3.0/24"]
    error_message = "Connector subnets must preserve their released availability zones and CIDRs."
  }
  assert {
    condition     = aws_subnet.egress_gateway[*].availability_zone == ["us-east-1d", "us-east-1e", "us-east-1d"] && aws_subnet.egress_gateway[*].cidr_block == ["10.255.4.0/24", "10.255.5.0/24", "10.255.6.0/24"]
    error_message = "Separate endpoint subnets must match the NLB zones without overlapping connector CIDRs."
  }
  assert {
    condition     = aws_cloudformation_stack.restricted_egress_connector.parameters.SubnetIds == join(",", aws_subnet.restricted_egress[*].id)
    error_message = "The upgrade plan must retain the existing connector subnet IDs."
  }
  assert {
    condition     = length(aws_route53_resolver_firewall_rule_group_association.restricted_egress) == 1 && aws_route53_resolver_firewall_rule.restricted_egress[0].action == "BLOCK" && aws_route53_resolver_firewall_domain_list.restricted_egress[0].domains == toset(["*."])
    error_message = "The managed VPC must retain its DNS block."
  }
}

run "existing_vpc_with_module_dns_firewall" {
  command = apply
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id                  = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id     = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id     = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id     = "subnet-0123456789abcdef2"
    manage_existing_vpc_dns_firewall = true
  }
  assert {
    condition = (
      aws_route53_resolver_firewall_rule_group_association.restricted_egress[0].vpc_id == var.existing_vpc_id
      && aws_route53_resolver_firewall_domain_list.egress_gateway[0].domains == toset(["${output.egress_gateway_dns_name}."])
      && aws_route53_resolver_firewall_domain_list.restricted_egress[0].domains == toset(["*."])
      && aws_route53_resolver_firewall_rule.egress_gateway_allow[0].action == "ALLOW"
      && aws_route53_resolver_firewall_rule.restricted_egress[0].action == "BLOCK"
      && aws_route53_resolver_firewall_rule.egress_gateway_allow[0].priority < aws_route53_resolver_firewall_rule.restricted_egress[0].priority
    )
    error_message = "Opting in must associate DNS Firewall with the supplied VPC and allow the created endpoint before blocking other names."
  }
}

run "existing_vpc_keeps_customer_network" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }
  assert {
    condition     = length(aws_vpc.restricted_egress) == 0 && length(aws_subnet.restricted_egress) == 0 && length(aws_subnet.egress_gateway) == 0 && length(aws_route_table.restricted_egress) == 0 && length(aws_route_table_association.restricted_egress) == 0 && length(aws_route_table_association.egress_gateway) == 0
    error_message = "The existing-VPC option must not create a VPC, subnets, or routes."
  }
  assert {
    condition     = length(aws_route53_resolver_firewall_rule_group_association.restricted_egress) == 0 && length(aws_route53_resolver_firewall_rule.restricted_egress) == 0 && length(aws_route53_resolver_firewall_rule.egress_gateway_allow) == 0
    error_message = "Turning DNS management off must leave DNS policy under the caller's control."
  }
  assert {
    condition     = aws_security_group.restricted_egress.vpc_id == "vpc-0123456789abcdef0"
    error_message = "The sandbox security group must live in the supplied VPC."
  }
  assert {
    condition     = aws_cloudformation_stack.restricted_egress_connector.parameters.SubnetIds == "subnet-0123456789abcdef0,subnet-0123456789abcdef1,subnet-0123456789abcdef2"
    error_message = "The connector must use the supplied subnets."
  }
}

run "rejects_missing_subnet" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = "subnet-0123456789abcdef1"
  }
  expect_failures = [var.existing_private_subnet_3_id]
}

run "rejects_empty_subnet_1_id" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = ""
    existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }
  expect_failures = [var.existing_private_subnet_1_id]
}

run "rejects_empty_subnet_2_id" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = " "
    existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }
  expect_failures = [var.existing_private_subnet_2_id]
}

run "rejects_empty_subnet_3_id" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id = "  "
  }
  expect_failures = [var.existing_private_subnet_3_id]
}

run "rejects_subnet_from_another_vpc" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }
  override_data {
    target = data.aws_subnet.restricted_egress_existing[0]
    values = { vpc_id = "vpc-99999999999999999" }
  }
  expect_failures = [data.aws_subnet.restricted_egress_existing[0]]
}

run "rejects_subnets_without_vpc" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
  }
  expect_failures = [var.existing_private_subnet_1_id]
}

run "rejects_duplicate_subnets" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = "subnet-0123456789abcdef0"
    existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }
  expect_failures = [var.existing_private_subnet_3_id]
}

# Mocked apply so the egress gateway endpoint DNS name is known when the
# assertions check the runtime URL and the DNS firewall allow list.
run "egress_gateway_in_managed_vpc" {
  command = apply
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }

  assert {
    condition = alltrue(flatten([
      for cidr, rules in {
        "169.254.169.253/32" = aws_vpc_security_group_egress_rule.sandbox_to_dns_link_local
        "10.255.0.2/32"      = aws_vpc_security_group_egress_rule.sandbox_to_dns_vpc
        } : [
        for protocol in ["tcp", "udp"] :
        rules[protocol].security_group_id == aws_security_group.restricted_egress.id
        && rules[protocol].cidr_ipv4 == cidr
        && rules[protocol].from_port == 53 && rules[protocol].to_port == 53
        && rules[protocol].ip_protocol == protocol
      ]
    ]))
    error_message = "Managed sandboxes must allow TCP and UDP DNS only to the link-local and VPC resolvers."
  }

  assert {
    condition = (
      aws_lb.egress_gateway.load_balancer_type == "network"
      && aws_lb.egress_gateway.internal
      && aws_lb.egress_gateway.enable_cross_zone_load_balancing
      && aws_lb.egress_gateway.enforce_security_group_inbound_rules_on_private_link_traffic == "off"
      && toset(aws_lb.egress_gateway.subnets) == toset(var.endpoint_subnet_ids)
      && aws_lb.egress_gateway.security_groups == toset([aws_security_group.egress_gateway_nlb.id])
    )
    error_message = "The egress gateway must be an internal NLB in the main VPC private subnets."
  }

  assert {
    condition = (
      aws_lb_target_group.egress_gateway.port == 4002
      && aws_lb_target_group.egress_gateway.protocol == "TCP"
      && aws_lb_target_group.egress_gateway.target_type == "ip"
      && aws_lb_target_group.egress_gateway.vpc_id == var.endpoint_vpc_id
      && aws_lb_target_group.egress_gateway.deregistration_delay == "900"
      && aws_lb_listener.egress_gateway.port == 4002
      && aws_lb_listener.egress_gateway.protocol == "TCP"
      && aws_lb_listener.egress_gateway.default_action[0].target_group_arn == aws_lb_target_group.egress_gateway.arn
    )
    error_message = "The NLB must forward TCP 4002 to the Loop runtime tasks."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.egress_gateway_nlb_to_runtime.security_group_id == aws_security_group.egress_gateway_nlb.id
      && aws_vpc_security_group_egress_rule.egress_gateway_nlb_to_runtime.referenced_security_group_id == var.runtime_security_group_id
      && aws_vpc_security_group_egress_rule.egress_gateway_nlb_to_runtime.from_port == 4002
      && aws_vpc_security_group_egress_rule.egress_gateway_nlb_to_runtime.to_port == 4002
    )
    error_message = "The NLB may only reach the Loop runtime tasks on port 4002."
  }

  assert {
    condition = (
      !aws_vpc_endpoint_service.egress_gateway.acceptance_required
      && aws_vpc_endpoint_service.egress_gateway.network_load_balancer_arns == toset([aws_lb.egress_gateway.arn])
      && aws_vpc_endpoint_service.egress_gateway.allowed_principals == toset(["arn:aws:iam::123456789012:root"])
    )
    error_message = "The endpoint service must front the NLB and allow only this account."
  }

  assert {
    condition = (
      aws_vpc_endpoint.egress_gateway.vpc_endpoint_type == "Interface"
      && aws_vpc_endpoint.egress_gateway.service_name == aws_vpc_endpoint_service.egress_gateway.service_name
      && aws_vpc_endpoint.egress_gateway.vpc_id == aws_vpc.restricted_egress[0].id
      && toset(aws_vpc_endpoint.egress_gateway.subnet_ids) == toset(aws_subnet.egress_gateway[*].id)
      && aws_vpc_endpoint.egress_gateway.security_group_ids == toset([aws_security_group.egress_gateway_endpoint.id])
      && !aws_vpc_endpoint.egress_gateway.private_dns_enabled
    )
    error_message = "The sandbox VPC must reach the gateway through an interface endpoint in its own subnets."
  }

  assert {
    condition = (
      aws_cloudformation_stack.restricted_egress_connector.parameters.SubnetIds == join(",", aws_subnet.restricted_egress[*].id)
      && alltrue([for association in aws_route_table_association.egress_gateway : association.route_table_id == aws_route_table.restricted_egress[0].id])
    )
    error_message = "The connector must keep its original subnets while the endpoint subnets use the isolated route table."
  }

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.egress_gateway_endpoint_from_sandbox.security_group_id == aws_security_group.egress_gateway_endpoint.id
      && aws_vpc_security_group_ingress_rule.egress_gateway_endpoint_from_sandbox.referenced_security_group_id == aws_security_group.restricted_egress.id
      && aws_vpc_security_group_ingress_rule.egress_gateway_endpoint_from_sandbox.from_port == 4002
      && aws_vpc_security_group_ingress_rule.egress_gateway_endpoint_from_sandbox.to_port == 4002
      && aws_vpc_security_group_egress_rule.sandbox_to_egress_gateway.referenced_security_group_id == aws_security_group.egress_gateway_endpoint.id
    )
    error_message = "Only sandboxes may reach the egress gateway endpoint, and only on port 4002."
  }

  assert {
    condition = (
      aws_route53_resolver_firewall_domain_list.egress_gateway[0].domains == toset(["vpce-0123456789abcdef0-abcdefgh.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com."])
      && aws_route53_resolver_firewall_rule.egress_gateway_allow[0].action == "ALLOW"
      && aws_route53_resolver_firewall_rule.egress_gateway_allow[0].priority < aws_route53_resolver_firewall_rule.restricted_egress[0].priority
      && aws_route53_resolver_firewall_rule.egress_gateway_allow[0].firewall_rule_group_id == aws_route53_resolver_firewall_rule_group.restricted_egress[0].id
    )
    error_message = "The managed DNS firewall must resolve only the egress gateway endpoint before it blocks every other name."
  }

  assert {
    condition     = output.sandbox_env_vars["LOOP_RUNTIME_SANDBOX_EGRESS_GATEWAY_URL"] == "http://vpce-0123456789abcdef0-abcdefgh.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com:4002"
    error_message = "The runtime must tell sandboxes to use the egress gateway endpoint."
  }

  assert {
    condition     = output.sandbox_env_vars["LOOP_RUNTIME_SANDBOX_FORWARD_PROXY_LISTEN"] == "0.0.0.0:4002"
    error_message = "The runtime must listen for sandbox egress on port 4002."
  }

  assert {
    condition     = output.sandbox_env_vars["AWS_LAMBDA_MICROVM_EGRESS_NETWORK_CONNECTOR_ARNS"] == "arn:aws:lambda:us-east-1:123456789012:network-connector:bt-loop-bt-test-restricted-egress"
    error_message = "Sandboxes must use only the restricted egress connector."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(output.task_role_policy_json).Statement :
      !anytrue([for resource in flatten([statement.Resource]) : endswith(resource, ":INTERNET_EGRESS")])
    ])
    error_message = "The Loop runtime task role must not pass the AWS internet egress connector."
  }
}

run "egress_gateway_in_existing_vpc" {
  command = apply
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }

  assert {
    condition = alltrue(flatten([
      for cidr, rules in {
        "169.254.169.253/32" = aws_vpc_security_group_egress_rule.sandbox_to_dns_link_local
        "172.20.0.2/32"      = aws_vpc_security_group_egress_rule.sandbox_to_dns_vpc
        } : [
        for protocol in ["tcp", "udp"] :
        rules[protocol].security_group_id == aws_security_group.restricted_egress.id
        && rules[protocol].cidr_ipv4 == cidr
        && rules[protocol].from_port == 53 && rules[protocol].to_port == 53
        && rules[protocol].ip_protocol == protocol
      ]
    ]))
    error_message = "Supplied-VPC sandboxes must derive the VPC resolver from its CIDR and allow only TCP and UDP port 53."
  }

  override_data {
    target = data.aws_subnet.egress_gateway_nlb[2]
    values = { availability_zone = "us-east-1b" }
  }

  override_data {
    target = data.aws_subnet.restricted_egress_existing[1]
    values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1a" }
  }

  override_data {
    target = data.aws_subnet.restricted_egress_existing[2]
    values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1b" }
  }

  assert {
    condition = (
      aws_vpc_endpoint.egress_gateway.vpc_id == var.existing_vpc_id
      && toset(aws_vpc_endpoint.egress_gateway.subnet_ids) == toset(["subnet-0123456789abcdef0", "subnet-0123456789abcdef2"])
      && aws_security_group.egress_gateway_endpoint.vpc_id == var.existing_vpc_id
      && toset(aws_lb.egress_gateway.subnets) == toset(slice(var.endpoint_subnet_ids, 0, 2))
      && toset(aws_vpc_endpoint.loop_runtime_microvm.subnet_ids) == toset(slice(var.endpoint_subnet_ids, 0, 2))
    )
    error_message = "The endpoints and NLB must select one subnet per matching zone."
  }

  assert {
    condition     = output.egress_gateway_dns_name == "vpce-0123456789abcdef0-abcdefgh.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com"
    error_message = "The module must expose the endpoint name that a supplied VPC's DNS policy has to allow."
  }
}

run "rejects_unsupported_endpoint_zones" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }

  override_data {
    target = data.aws_subnet.egress_gateway_nlb[0]
    values = { availability_zone = "us-east-1d" }
  }
  override_data {
    target = data.aws_subnet.egress_gateway_nlb[1]
    values = { availability_zone = "us-east-1e" }
  }
  override_data {
    target = data.aws_subnet.egress_gateway_nlb[2]
    values = { availability_zone = "us-east-1f" }
  }

  expect_failures = [aws_vpc_endpoint.egress_gateway]
}
