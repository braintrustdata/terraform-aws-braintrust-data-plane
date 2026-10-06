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

run "ssm_default_keeps_all_endpoints" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    enable_brainstore_ec2_ssm           = true
    create_secrets_manager_vpc_endpoint = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.ec2_ssm_endpoint) == 3
    error_message = "SSM endpoints must respect both SSM enablement and endpoint opt-out."
  }

  assert {
    condition     = length(aws_vpc_endpoint.secrets_manager) == 0
    error_message = "SSM settings must not change Secrets Manager endpoint creation."
  }

  assert {
    condition     = length(aws_security_group.vpc_endpoints_tls) == 1
    error_message = "Keep the shared security group exactly when an interface endpoint needs it."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "SSM settings must preserve the S3 gateway endpoint."
  }

  assert {
    condition     = toset(keys(aws_vpc_endpoint.ec2_ssm_endpoint)) == toset(["ssm", "ssmmessages", "ec2messages"])
    error_message = "Preserve the existing SSM endpoint resource keys for upgrades."
  }
}

run "ssm_opt_out_keeps_secrets_manager" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    enable_brainstore_ec2_ssm           = true
    create_secrets_manager_vpc_endpoint = true
    create_ssm_vpc_endpoints            = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.ec2_ssm_endpoint) == 0
    error_message = "SSM endpoints must respect both SSM enablement and endpoint opt-out."
  }

  assert {
    condition     = length(aws_vpc_endpoint.secrets_manager) == 1
    error_message = "SSM settings must not change Secrets Manager endpoint creation."
  }

  assert {
    condition     = length(aws_security_group.vpc_endpoints_tls) == 1
    error_message = "Keep the shared security group exactly when an interface endpoint needs it."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "SSM settings must preserve the S3 gateway endpoint."
  }
}

run "ssm_opt_out_removes_unused_security_group" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    enable_brainstore_ec2_ssm           = true
    create_secrets_manager_vpc_endpoint = false
    create_ssm_vpc_endpoints            = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.ec2_ssm_endpoint) == 0
    error_message = "SSM endpoints must respect both SSM enablement and endpoint opt-out."
  }

  assert {
    condition     = length(aws_vpc_endpoint.secrets_manager) == 0
    error_message = "SSM settings must not change Secrets Manager endpoint creation."
  }

  assert {
    condition     = length(aws_security_group.vpc_endpoints_tls) == 0
    error_message = "Keep the shared security group exactly when an interface endpoint needs it."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "SSM settings must preserve the S3 gateway endpoint."
  }
}

run "ssm_disabled_keeps_secrets_manager" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    enable_brainstore_ec2_ssm           = false
    create_secrets_manager_vpc_endpoint = true
  }

  assert {
    condition     = length(aws_vpc_endpoint.ec2_ssm_endpoint) == 0
    error_message = "SSM endpoints must respect both SSM enablement and endpoint opt-out."
  }

  assert {
    condition     = length(aws_vpc_endpoint.secrets_manager) == 1
    error_message = "SSM settings must not change Secrets Manager endpoint creation."
  }

  assert {
    condition     = length(aws_security_group.vpc_endpoints_tls) == 1
    error_message = "Keep the shared security group exactly when an interface endpoint needs it."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "SSM settings must preserve the S3 gateway endpoint."
  }
}

run "ssm_disabled_creates_no_interface_endpoints" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    enable_brainstore_ec2_ssm           = false
    create_secrets_manager_vpc_endpoint = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.ec2_ssm_endpoint) == 0
    error_message = "SSM endpoints must respect both SSM enablement and endpoint opt-out."
  }

  assert {
    condition     = length(aws_vpc_endpoint.secrets_manager) == 0
    error_message = "SSM settings must not change Secrets Manager endpoint creation."
  }

  assert {
    condition     = length(aws_security_group.vpc_endpoints_tls) == 0
    error_message = "Keep the shared security group exactly when an interface endpoint needs it."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "SSM settings must preserve the S3 gateway endpoint."
  }
}

run "both_endpoint_families_enabled" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    enable_brainstore_ec2_ssm           = true
    create_secrets_manager_vpc_endpoint = true
    create_ssm_vpc_endpoints            = true
  }

  assert {
    condition     = length(aws_vpc_endpoint.ec2_ssm_endpoint) == 3
    error_message = "SSM endpoints must respect both SSM enablement and endpoint opt-out."
  }

  assert {
    condition     = length(aws_vpc_endpoint.secrets_manager) == 1
    error_message = "SSM settings must not change Secrets Manager endpoint creation."
  }

  assert {
    condition     = length(aws_security_group.vpc_endpoints_tls) == 1
    error_message = "Keep the shared security group exactly when an interface endpoint needs it."
  }

  assert {
    condition     = aws_vpc_endpoint.s3.vpc_endpoint_type == "Gateway"
    error_message = "SSM settings must preserve the S3 gateway endpoint."
  }

  assert {
    condition     = toset(keys(aws_vpc_endpoint.ec2_ssm_endpoint)) == toset(["ssm", "ssmmessages", "ec2messages"])
    error_message = "Preserve the existing SSM endpoint resource keys for upgrades."
  }
}

