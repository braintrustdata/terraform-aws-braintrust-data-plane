# Generate the real endpoint policy locally. The caller identity is overridden
# below so these plan-only runs make no AWS API calls.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:role/test"
    user_id    = "test"
  }
}

variables {
  sandbox_service_stack_name = "bt-test-sandbox-service"
  deployment_name            = "bt-test"
  vpc_name                   = "main"
  vpc_cidr                   = "10.175.0.0/21"
  public_subnet_1_cidr       = "10.175.0.0/24"
  public_subnet_1_az         = "us-east-1a"
  private_subnet_1_cidr      = "10.175.1.0/24"
  private_subnet_1_az        = "us-east-1a"
  private_subnet_2_cidr      = "10.175.2.0/24"
  private_subnet_2_az        = "us-east-1b"
  private_subnet_3_cidr      = "10.175.3.0/24"
  private_subnet_3_az        = "us-east-1c"
}

run "org_restricted_endpoint_allows_only_the_pinned_chart" {
  command = plan
  module {
    source = "./modules/vpc"
  }
  variables {
    create_sandbox_subnets           = true
    s3_vpc_endpoint_resource_org_ids = ["o-1234567890"]
    sandbox_service_chart_object_arn = "arn:aws:s3:::braintrust-cf-us-east-1/${jsondecode(file("modules/sandbox-service/VERSIONS.json"))["chart-key"]}"
  }
  assert {
    condition = (
      one([for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement : statement if statement.Sid == "AllowSandboxServiceChart"]) == {
        Sid       = "AllowSandboxServiceChart"
        Effect    = "Allow"
        Action    = "s3:GetObject"
        Resource  = var.sandbox_service_chart_object_arn
        Principal = "*"
      } &&
      one([for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement : statement if statement.Sid == "AllowSandboxServiceResponses"]) == {
        Sid       = "AllowSandboxServiceResponses"
        Effect    = "Allow"
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::cloudformation-custom-resource-response-useast1/arn:aws:cloudformation:us-east-1:123456789012:stack/${var.sandbox_service_stack_name}/*"
        Principal = "*"
      } &&
      contains([for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement : statement.Sid], "AllowS3InAllowedOrganizations")
    )
    error_message = "An organization-restricted endpoint must allow GetObject on the pinned chart without relaxing its other restrictions."
  }
}

run "account_restricted_endpoint_allows_the_pinned_chart" {
  command = plan
  module {
    source = "./modules/vpc"
  }
  variables {
    create_sandbox_subnets               = true
    s3_vpc_endpoint_resource_account_ids = ["111122223333"]
    sandbox_service_chart_object_arn     = "arn:aws:s3:::braintrust-cf-us-east-1/${jsondecode(file("modules/sandbox-service/VERSIONS.json"))["chart-key"]}"
  }
  assert {
    condition = (
      one([for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement : statement if statement.Sid == "AllowSandboxServiceChart"]).Resource == var.sandbox_service_chart_object_arn &&
      one([for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement : statement if statement.Sid == "AllowS3InAllowedAccounts"]).Condition.StringEquals["aws:ResourceAccount"] == ["111122223333", "123456789012"]
    )
    error_message = "An account-restricted endpoint must admit the chart while preserving the configured and deployment account allowlist."
  }
}

run "disabled_sandbox_retains_its_stack_response_permission" {
  command = plan
  module {
    source = "./modules/vpc"
  }
  variables {
    s3_vpc_endpoint_resource_org_ids = ["o-1234567890"]
  }
  assert {
    condition = (
      !contains([for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement : statement.Sid], "AllowSandboxServiceChart") &&
      one([for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement : statement if statement.Sid == "AllowSandboxServiceResponses"]).Resource == "arn:aws:s3:::cloudformation-custom-resource-response-useast1/arn:aws:cloudformation:us-east-1:123456789012:stack/${var.sandbox_service_stack_name}/*"
    )
    error_message = "Disabling sandboxes must remove chart access while retaining the response upload required to complete stack deletion."
  }
}

run "unrestricted_endpoint_needs_no_artifact_exception" {
  command = plan
  module {
    source = "./modules/vpc"
  }
  variables {
    create_sandbox_subnets           = true
    sandbox_service_chart_object_arn = "arn:aws:s3:::braintrust-cf-us-east-1/${jsondecode(file("modules/sandbox-service/VERSIONS.json"))["chart-key"]}"
  }
  assert {
    condition     = jsondecode(aws_vpc_endpoint.s3.policy).Statement == [{ Effect = "Allow", Action = "s3:*", Resource = "*", Principal = "*" }]
    error_message = "An unrestricted endpoint must retain its existing policy without redundant artifact permissions."
  }
}

run "unrelated_vpc_keeps_existing_restrictions" {
  command = plan
  module {
    source = "./modules/vpc"
  }
  variables {
    vpc_name                         = "quarantine"
    s3_vpc_endpoint_resource_org_ids = ["o-1234567890"]
    sandbox_service_stack_name       = null
  }
  assert {
    condition = length(setintersection(
      toset([for statement in jsondecode(aws_vpc_endpoint.s3.policy).Statement : statement.Sid]),
      toset(["AllowSandboxServiceChart", "AllowSandboxServiceResponses"]),
    )) == 0
    error_message = "VPCs without the Sandbox Service stack must not gain chart or response permissions."
  }
}
