# Generation profile for modules/kms. See iam.tftest.hcl.

# The module's postcondition compares the Auto Scaling service-linked role to a
# literal arn:aws: ARN, so this file keeps the repository mock's role data
# source, which returns that ARN.
mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_data "aws_partition" {
    defaults = { partition = "aws-manifest", dns_suffix = "amazonaws.com" }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

run "kms_key_policy" {
  command = apply
  module { source = "./modules/kms" }

  variables {
    deployment_name = "bt-manifest"
  }
}
