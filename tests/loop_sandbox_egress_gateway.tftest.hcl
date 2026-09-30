# Mocked apply so the egress gateway endpoint DNS name is known when the
# assertions check the runtime URL and the DNS firewall allow list.
mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1a" }
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
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-test-loop-egress/1111111111111111"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222"
    }
  }
  mock_resource "aws_vpc_endpoint_service" {
    defaults = {
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0123456789abcdef0"
    }
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

run "egress_gateway_in_managed_vpc" {
  command = apply
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
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
      && output.egress_gateway_target_group_arn == aws_lb_target_group.egress_gateway.arn
    )
    error_message = "The NLB must forward TCP 4002 to the Loop runtime tasks."
  }

  assert {
    condition = (
      aws_vpc_security_group_egress_rule.egress_gateway_nlb_to_runtime.security_group_id == aws_security_group.egress_gateway_nlb.id
      && aws_vpc_security_group_egress_rule.egress_gateway_nlb_to_runtime.referenced_security_group_id == var.runtime_security_group_id
      && aws_vpc_security_group_egress_rule.egress_gateway_nlb_to_runtime.from_port == 4002
      && aws_vpc_security_group_egress_rule.egress_gateway_nlb_to_runtime.to_port == 4002
      && output.egress_gateway_security_group_id == aws_security_group.egress_gateway_nlb.id
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
      && toset(aws_vpc_endpoint.egress_gateway.subnet_ids) == toset(aws_subnet.restricted_egress[*].id)
      && aws_vpc_endpoint.egress_gateway.security_group_ids == toset([aws_security_group.egress_gateway_endpoint.id])
      && !aws_vpc_endpoint.egress_gateway.private_dns_enabled
    )
    error_message = "The sandbox VPC must reach the gateway through an interface endpoint in its own subnets."
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

  override_data {
    target = data.aws_subnet.egress_gateway_nlb[2]
    values = { availability_zone = "us-east-1b" }
  }

  override_data {
    target = data.aws_subnet.restricted_egress_existing[0]
    values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1a" }
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
