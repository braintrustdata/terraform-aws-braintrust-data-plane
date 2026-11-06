# Stand in for subnets created by another module in the same apply. The output
# is unknown during plan even though the input values and list lengths are known.
resource "terraform_data" "subnets" {
  input = {
    main       = ["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]
    quarantine = ["subnet-44444444444444444", "subnet-55555555555555555", "subnet-66666666666666666"]
  }
}

module "dataplane" {
  source = "../../.."

  deployment_name                      = "bt-test"
  braintrust_org_name                  = "test-org"
  primary_org_name                     = "test-org"
  brainstore_license_key               = "test-license"
  enable_ecs_api                       = true
  create_ai_gateway                    = true
  enable_quarantine_vpc                = true
  use_private_gateway_quarantine_proxy = true

  create_vpc                   = false
  existing_vpc_id              = "vpc-11111111111111111"
  existing_public_subnet_1_id  = "subnet-77777777777777777"
  existing_private_subnet_1_id = terraform_data.subnets.output.main[0]
  existing_private_subnet_2_id = terraform_data.subnets.output.main[1]
  existing_private_subnet_3_id = terraform_data.subnets.output.main[2]

  existing_quarantine_vpc_id              = "vpc-22222222222222222"
  existing_quarantine_private_subnet_1_id = terraform_data.subnets.output.quarantine[0]
  existing_quarantine_private_subnet_2_id = terraform_data.subnets.output.quarantine[1]
  existing_quarantine_private_subnet_3_id = terraform_data.subnets.output.quarantine[2]
}
