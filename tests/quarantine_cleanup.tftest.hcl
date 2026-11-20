# Plan-only regressions for native cleanup and deployment mode compatibility.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name    = "cleanup-test"
  deployment_name        = "cleanup-test"
  primary_org_name       = "cleanup-test"
  brainstore_license_key = "test-license"
}

run "quarantine_enabled" {
  command = plan
}
run "quarantine_disabled" {
  command = plan
  variables { enable_quarantine_vpc = false }
}
run "external_eks" {
  command = plan
  variables { use_deployment_mode_external_eks = true }
}

run "caller_provided_quarantine_network" {
  command = plan
  variables {
    enable_quarantine_destroy_cleanup       = true
    existing_quarantine_vpc_id              = "vpc-1234567890abcdef0"
    existing_quarantine_private_subnet_1_id = "subnet-11111111111111111"
    existing_quarantine_private_subnet_2_id = "subnet-22222222222222222"
    existing_quarantine_private_subnet_3_id = "subnet-33333333333333333"
  }
}

run "native_cleanup_enabled" {
  command = plan
  variables { enable_quarantine_destroy_cleanup = true }
  assert {
    condition     = length(module.services) == 1
    error_message = "Native cleanup requires module-managed consumers."
  }
}

run "external_eks_cannot_enable_cleanup" {
  command = plan
  variables {
    use_deployment_mode_external_eks  = true
    enable_quarantine_destroy_cleanup = true
  }
  expect_failures = [var.enable_quarantine_destroy_cleanup]
}
