mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" { defaults = { partition = "aws", dns_suffix = "amazonaws.com" } }
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

# The caller's secret ARN remains unknown during this plan.
run "caller_creates_license_in_same_apply" {
  command = plan
  module { source = "./tests/fixtures/computed-license-secret" }
  providers = {
    aws    = aws
    http   = http
    random = random
  }
}
