mock_provider "aws" {
  source = "./tests/mocks/aws"
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

run "existing_service_linked_role_preserves_key_policy" {
  command = plan
  module { source = "./modules/kms" }
  variables { deployment_name = "bt-test" }

  assert {
    condition = (
      jsondecode(aws_kms_key.braintrust.policy).Statement[1].Principal.AWS == ["arn:aws:iam::123456789012:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"] &&
      jsondecode(aws_kms_key.braintrust.policy).Statement[3].Principal.AWS == ["arn:aws:iam::123456789012:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    )
    error_message = "Reading the account prerequisite must preserve both existing KMS principal grants."
  }
}

run "rejects_unusable_service_linked_role" {
  command = plan
  module { source = "./modules/kms" }
  variables { deployment_name = "bt-test" }
  override_data {
    target = data.aws_iam_role.autoscaling_service_linked_role
    values = { arn = "" }
  }
  expect_failures = [data.aws_iam_role.autoscaling_service_linked_role]
}

run "external_key_skips_module_owned_key_check" {
  command = plan
  variables {
    deployment_name        = "bt-test"
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    brainstore_license_key = "test-license"
    kms_key_arn            = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }
  assert {
    condition     = length(module.kms) == 0
    error_message = "Externally managed keys must not instantiate the KMS module or its prerequisite lookup."
  }
}
