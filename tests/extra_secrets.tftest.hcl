# Plan-mode coverage for ARN-only ECS extra_secrets wiring.
# Ensures gateway/API can plan with consumer secrets as valueFrom ARNs
# (not secret_string in *_extra_env_vars).

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

run "extra_secrets_arn_only_plans" {
  command = plan

  variables {
    braintrust_org_name              = "test-org"
    brainstore_license_key           = null
    use_deployment_mode_external_eks = true
    enable_quarantine_vpc            = false
    create_ai_gateway                = false
    enable_ecs_api                   = false

    ai_gateway_extra_env_vars = {
      NATIVE_INFERENCE_ENVIRONMENT = "eu"
    }
    ai_gateway_extra_secrets = [
      {
        name      = "NATIVE_INFERENCE_SECRET_KEY"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:native-inference-AbCdEf"
      }
    ]
    braintrust_api_extra_secrets = [
      {
        name      = "LAUNCHDARKLY_SDK_KEY"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:launchdarkly-XyZ123:::01234567-89ab-cdef-0123-456789abcdef"
      }
    ]
  }
}

run "extra_env_denylist_rejects_secret_key" {
  command = plan

  variables {
    braintrust_org_name              = "test-org"
    brainstore_license_key           = null
    use_deployment_mode_external_eks = true
    enable_quarantine_vpc            = false

    ai_gateway_extra_env_vars = {
      NATIVE_INFERENCE_SECRET_KEY = "should-fail-validation"
    }
  }

  expect_failures = [
    var.ai_gateway_extra_env_vars,
  ]
}
