# Plan-mode coverage for brainstore_license_key = null.
# terraform validate treats variables as unknown and will not catch coalesce(null, "")
# style regressions; command = plan forces evaluation of local.brainstore_license_key_provided.
#
# Depends on the INF-178 null-safe ternary in main.tf.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az4"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:root"
      user_id    = "AIDACKCEVSQ6C2EXAMPLE"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name   = "us-east-1"
      region = "us-east-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
}

mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "test-version"
    }
  }
}

mock_provider "random" {}

run "license_key_unset_plans" {
  command = plan

  variables {
    braintrust_org_name              = "test-org"
    brainstore_license_key           = null
    use_deployment_mode_external_eks = true
    enable_quarantine_vpc            = false
  }
}
