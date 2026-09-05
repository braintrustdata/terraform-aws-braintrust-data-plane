# CloudFront VPC-origin AZ filtering: excluded zone IDs drop off origin ALBs only.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

override_data {
  target = data.aws_availability_zones.available
  values = {
    names    = ["us-east-1a", "us-east-1e", "us-east-1c"]
    zone_ids = ["use1-az1", "use1-az3", "use1-az4"]
  }
}

variables {
  braintrust_org_name           = "test-org"
  primary_org_name              = "test-org"
  deployment_name               = "bt-test"
  brainstore_license_key        = "test-license"
  enable_quarantine_vpc         = true
  create_ai_gateway             = true
  enable_ai_gateway             = true
  use_private_ai_gateway_origin = true
}

run "filters_origin_albs_off_excluded_az" {
  command = plan

  assert {
    condition     = length(output.cloudfront_vpc_origin_safe_zone_ids) == 2
    error_message = "Only two main-VPC AZs should remain after excluding use1-az3"
  }

  assert {
    condition     = !contains(output.cloudfront_vpc_origin_safe_zone_ids, "use1-az3")
    error_message = "Excluded zone ID use1-az3 should not appear in the safe set"
  }
}

run "rejects_only_one_cloudfront_safe_subnet" {
  command = plan

  variables {
    private_subnet_1_az = "us-east-1a"
    private_subnet_2_az = "us-east-1e"
    private_subnet_3_az = "us-east-1e"
  }

  expect_failures = [
    check.cloudfront_vpc_origin_subnet_validation,
  ]
}

run "rejects_duplicate_cloudfront_safe_azs" {
  command = plan

  variables {
    private_subnet_1_az = "us-east-1a"
    private_subnet_2_az = "us-east-1c"
    private_subnet_3_az = "us-east-1c"
  }

  expect_failures = [
    check.cloudfront_vpc_origin_subnet_validation,
  ]
}
