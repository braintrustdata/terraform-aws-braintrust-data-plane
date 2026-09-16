mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }
}
mock_provider "http" {
  source = "./tests/mocks/http"
}
variables {
  deployment_name     = "bt-test"
  microvm_version_tag = "test"
}

run "managed_isolation_by_default" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }

  assert {
    condition     = length(aws_vpc.restricted_egress) == 1 && length(aws_subnet.restricted_egress) == 3
    error_message = "Restricted mode must create a dedicated VPC and three subnets by default."
  }
  assert {
    condition     = length(aws_route53_resolver_firewall_rule_group_association.restricted_egress) == 1 && aws_route53_resolver_firewall_rule.restricted_egress[0].action == "BLOCK" && aws_route53_resolver_firewall_domain_list.restricted_egress[0].domains == toset(["*."])
    error_message = "The managed VPC must retain its DNS block."
  }
  assert {
    condition     = length(aws_security_group.restricted_egress[0].egress) == 0
    error_message = "The sandbox security group must have no outbound rules."
  }
}

run "existing_vpc_keeps_customer_network" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id     = "vpc-0123456789abcdef0"
    existing_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  }
  assert {
    condition     = length(aws_vpc.restricted_egress) == 0 && length(aws_subnet.restricted_egress) == 0 && length(aws_route_table.restricted_egress) == 0 && length(aws_route_table_association.restricted_egress) == 0
    error_message = "The existing-VPC option must not create a VPC, subnets, or routes."
  }
  assert {
    condition     = length(aws_route53_resolver_firewall_rule_group_association.restricted_egress) == 0 && length(aws_route53_resolver_firewall_rule.restricted_egress) == 0
    error_message = "The module must not change DNS policy in a supplied VPC."
  }
  assert {
    condition     = aws_security_group.restricted_egress[0].vpc_id == "vpc-0123456789abcdef0" && length(aws_security_group.restricted_egress[0].egress) == 0
    error_message = "The supplied VPC must retain a dedicated security group without outbound rules."
  }
  assert {
    condition     = aws_cloudformation_stack.restricted_egress_connector[0].parameters.SubnetIds == "subnet-0123456789abcdef0,subnet-0123456789abcdef1"
    error_message = "The connector must use the supplied subnets."
  }
}

run "internet_mode_skips_restricted_network" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    sandbox_egress_mode = "internet"
  }
  assert {
    condition     = length(aws_vpc.restricted_egress) == 0 && length(aws_cloudformation_stack.restricted_egress_connector) == 0
    error_message = "Explicit internet mode must skip the restricted network."
  }
}

run "rejects_existing_vpc_with_internet" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id     = "vpc-0123456789abcdef0"
    existing_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    sandbox_egress_mode = "internet"
  }
  expect_failures = [var.existing_vpc_id]
}

run "rejects_empty_subnets" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id     = "vpc-0123456789abcdef0"
    existing_subnet_ids = []
  }
  expect_failures = [var.existing_subnet_ids]
}

run "rejects_subnet_from_another_vpc" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id     = "vpc-0123456789abcdef0"
    existing_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
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
    existing_subnet_ids = ["subnet-0123456789abcdef0"]
  }
  expect_failures = [var.existing_subnet_ids]
}

run "rejects_duplicate_subnets" {
  command = plan
  module {
    source = "./modules/loop-runtime-sandbox-aws-microvm"
  }
  variables {
    existing_vpc_id     = "vpc-0123456789abcdef0"
    existing_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef0"]
  }
  expect_failures = [var.existing_subnet_ids]
}
