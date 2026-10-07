# Mocked plans cover default enablement, SSM independence, opt-out, and
# existing-VPC compatibility where the main VPC module is not instantiated.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  deployment_name        = "bt-test"
  brainstore_license_key = "test-license"
}

run "secrets_manager_without_ssm" {
  command = plan

  variables {
    enable_brainstore_ec2_ssm = false
  }
}

run "secrets_manager_with_ssm" {
  command = plan

  variables {
    enable_brainstore_ec2_ssm = true
  }
}

run "secrets_manager_opt_out" {
  command = plan

  variables {
    create_secrets_manager_vpc_endpoint = false
  }
}

run "existing_vpc_skips_endpoint" {
  command = plan

  variables {
    create_vpc                   = false
    existing_vpc_id              = "vpc-12345678"
    existing_private_subnet_1_id = "subnet-11111111"
    existing_private_subnet_2_id = "subnet-22222222"
    existing_private_subnet_3_id = "subnet-33333333"
    existing_public_subnet_1_id  = "subnet-44444444"
  }

  assert {
    condition     = length(module.main_vpc) == 0
    error_message = "An existing main VPC must not instantiate the VPC module or its endpoints."
  }
}
