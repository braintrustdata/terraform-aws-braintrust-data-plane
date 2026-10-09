# Root-module wiring: custom subnet groups and endpoint opt-out work together.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name                    = "test-org"
  primary_org_name                       = "test-org"
  deployment_name                        = "bt-test"
  brainstore_license_key                 = "test-license"
  existing_elasticache_subnet_group_name = "shared-redis-subnets"
  enable_brainstore_ec2_ssm              = true
  create_ssm_vpc_endpoints               = false
}

run "managed_vpc_legacy_redis" {
  command = plan
}

run "managed_vpc_tls_redis" {
  command = plan

  variables {
    use_redis_replication_group = true
  }
}

run "existing_vpc_tls_redis" {
  command = plan

  variables {
    use_redis_replication_group  = true
    create_vpc                   = false
    existing_vpc_id              = "vpc-12345678"
    existing_private_subnet_1_id = "subnet-11111111"
    existing_private_subnet_2_id = "subnet-22222222"
    existing_private_subnet_3_id = "subnet-33333333"
    existing_public_subnet_1_id  = "subnet-44444444"
  }

  assert {
    condition     = length(module.main_vpc) == 0
    error_message = "Existing VPCs must not create a main VPC or its endpoints."
  }
}

run "rejects_empty_group" {
  command = plan

  variables {
    existing_elasticache_subnet_group_name = ""
  }

  expect_failures = [var.existing_elasticache_subnet_group_name]
}
