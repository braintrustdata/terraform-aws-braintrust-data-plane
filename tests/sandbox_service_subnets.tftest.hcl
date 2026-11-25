# Exercise the endpoint lifecycle independently of Brainstore SSM permissions.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name       = "bt-test"
  vpc_name              = "main"
  vpc_cidr              = "10.175.0.0/21"
  public_subnet_1_cidr  = "10.175.0.0/24"
  public_subnet_1_az    = "us-east-1a"
  private_subnet_1_cidr = "10.175.1.0/24"
  private_subnet_1_az   = "us-east-1a"
  private_subnet_2_cidr = "10.175.2.0/24"
  private_subnet_2_az   = "us-east-1b"
  private_subnet_3_cidr = "10.175.3.0/24"
  private_subnet_3_az   = "us-east-1c"
}

run "disabled_preserves_existing_network" {
  command = plan
  module {
    source = "./modules/vpc"
  }
  assert {
    condition     = length(aws_subnet.sandbox_private_subnet_1) == 0 && length(aws_network_acl.sandbox) == 0 && length(output.sandbox_private_subnet_ids) == 0
    error_message = "Disabled sandbox infrastructure must leave the existing network unchanged."
  }
}

run "dedicated_subnets_and_allowlisted_connections" {
  command = apply
  module {
    source = "./modules/vpc"
  }
  variables {
    create_sandbox_subnets = true
  }
  assert {
    condition = (
      aws_subnet.sandbox_private_subnet_1[0].cidr_block == "10.175.4.0/24" &&
      aws_subnet.sandbox_private_subnet_2[0].cidr_block == "10.175.5.0/24" &&
      aws_subnet.sandbox_private_subnet_3[0].cidr_block == "10.175.6.0/24" &&
      aws_subnet.private_subnet_1.cidr_block == "10.175.1.0/24" &&
      aws_route_table_association.sandbox_private_subnet_1[0].route_table_id == aws_route_table.private_route_table.id &&
      length(aws_network_acl_association.sandbox) == 3 &&
      aws_network_acl_association.sandbox["1"].subnet_id == aws_subnet.sandbox_private_subnet_1[0].id
    )
    error_message = "Sandbox subnets must use separate address space, existing NAT routing, and their own ACL."
  }
  assert {
    condition = (
      aws_network_acl_rule.sandbox_runtime_ingress["1"].from_port == 9400 &&
      aws_network_acl_rule.sandbox_runtime_ingress["1"].cidr_block == "10.175.1.0/24" &&
      aws_network_acl_rule.sandbox_proxy_egress["1"].from_port == 4002 &&
      aws_network_acl_rule.sandbox_runtime_discovery_ingress["1"].from_port == 443 &&
      aws_network_acl_rule.sandbox_runtime_return_egress["1"].from_port == 32768 &&
      aws_network_acl_rule.sandbox_private_egress["0"].cidr_block == var.vpc_cidr &&
      aws_network_acl_rule.sandbox_private_egress["0"].rule_action == "deny" &&
      aws_network_acl_rule.sandbox_private_egress["0"].rule_number < aws_network_acl_rule.sandbox_public_https[0].rule_number &&
      aws_network_acl_rule.sandbox_private_ingress["0"].rule_number < aws_network_acl_rule.sandbox_public_return[0].rule_number &&
      aws_network_acl_rule.sandbox_public_https[0].from_port == 443 &&
      aws_network_acl_rule.sandbox_public_return[0].from_port == 1024 &&
      aws_network_acl_rule.sandbox_public_return[0].to_port == 65535 &&
      aws_network_acl.sandbox[0].tags.BraintrustDeploymentName == var.deployment_name
    )
    error_message = "ACL ordering must admit runtime, discovery, proxy and return traffic before denying other private access."
  }
}
