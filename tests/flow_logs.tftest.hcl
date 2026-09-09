# Plan-mode tests for optional VPC Flow Logs destination modes.
# Primary signal: plan succeeds. Assert only values known at plan time
# (null unused destinations, caller-provided ARNs). Resource IDs are unknown
# until apply.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  deployment_name        = "bt-test"
  brainstore_license_key = "test-license"
  enable_quarantine_vpc  = true
}

run "managed_s3_plans" {
  command = plan

  variables {
    main_vpc_flow_log = {
      enabled = true
    }
  }

  assert {
    condition     = module.main_vpc[0].flow_log_enabled
    error_message = "managed S3 Flow Logs should be enabled"
  }

  assert {
    condition     = module.main_vpc[0].flow_log_cloudwatch_log_group_arn == null
    error_message = "managed S3 Flow Logs should not create a CloudWatch log group"
  }
}

run "managed_cloudwatch_plans" {
  command = plan

  variables {
    main_vpc_flow_log = {
      enabled          = true
      destination_type = "cloud-watch-logs"
    }
  }

  assert {
    condition     = module.main_vpc[0].flow_log_enabled
    error_message = "CloudWatch Flow Logs should be enabled"
  }

  assert {
    condition     = module.main_vpc[0].flow_log_s3_bucket_arn == null
    error_message = "CloudWatch Flow Logs should not create an S3 bucket"
  }
}

run "customer_s3_plans" {
  command = plan

  variables {
    main_vpc_flow_log = {
      enabled         = true
      destination_arn = "arn:aws:s3:::customer-flow-logs"
    }
  }

  assert {
    condition     = module.main_vpc[0].flow_log_destination_arn == "arn:aws:s3:::customer-flow-logs"
    error_message = "customer S3 Flow Logs should use the caller-provided bucket ARN"
  }

  assert {
    condition     = module.main_vpc[0].flow_log_s3_bucket_arn == null
    error_message = "customer S3 Flow Logs should not create a module-managed bucket"
  }

  assert {
    condition     = module.main_vpc[0].flow_log_cloudwatch_log_group_arn == null
    error_message = "customer S3 Flow Logs should not create a CloudWatch log group"
  }
}

run "customer_cloudwatch_strips_wildcard_suffix" {
  command = plan

  variables {
    main_vpc_flow_log = {
      enabled          = true
      destination_type = "cloud-watch-logs"
      destination_arn  = "arn:aws:logs:us-east-1:123456789012:log-group:my-flow-logs:*"
    }
  }

  assert {
    condition     = module.main_vpc[0].flow_log_destination_arn == "arn:aws:logs:us-east-1:123456789012:log-group:my-flow-logs"
    error_message = "customer CloudWatch ARNs that end in :* should be trimmed to the bare log-group ARN"
  }

  assert {
    condition     = module.main_vpc[0].flow_log_cloudwatch_log_group_arn == null
    error_message = "customer CloudWatch Flow Logs should not create a log group"
  }
}
