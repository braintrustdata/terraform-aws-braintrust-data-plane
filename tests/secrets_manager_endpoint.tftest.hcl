# Mocked plans verify the endpoint works independently of SSM and rejects
# existing-VPC configurations where this module cannot create the endpoint.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name                 = "test-org"
  primary_org_name                    = "test-org"
  deployment_name                     = "bt-test"
  brainstore_license_key              = "test-license"
  create_secrets_manager_vpc_endpoint = true
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

run "existing_vpc_rejected" {
  command = plan

  variables {
    create_vpc                   = false
    existing_vpc_id              = "vpc-12345678"
    existing_private_subnet_1_id = "subnet-11111111"
    existing_private_subnet_2_id = "subnet-22222222"
    existing_private_subnet_3_id = "subnet-33333333"
    existing_public_subnet_1_id  = "subnet-44444444"
  }

  expect_failures = [var.create_secrets_manager_vpc_endpoint]
}
