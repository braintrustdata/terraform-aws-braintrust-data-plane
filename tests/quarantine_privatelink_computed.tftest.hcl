mock_provider "aws" {
  source = "./tests/mocks/aws"
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

# No VPC or module overrides: generated subnet IDs remain unknown until apply.
run "new_managed_vpcs_plan_without_known_subnet_ids" {
  command = plan
  variables {
    deployment_name                      = "bt-test"
    braintrust_org_name                  = "test-org"
    primary_org_name                     = "test-org"
    brainstore_license_key               = "test-license"
    enable_ecs_api                       = true
    create_ai_gateway                    = true
    enable_quarantine_vpc                = true
    use_private_gateway_quarantine_proxy = true
  }
  assert {
    condition = (
      length(data.aws_subnet.quarantine_privatelink_main) == 3 &&
      length(data.aws_subnet.quarantine_privatelink_quarantine) == 3 &&
      length(aws_vpc_endpoint.quarantine_gateway) == 1
    )
    error_message = "PrivateLink must plan when both managed VPCs are being created."
  }
}

run "existing_subnets_created_in_same_apply_plan" {
  command = plan
  module {
    source = "./tests/fixtures/quarantine-computed-subnets"
  }
}
