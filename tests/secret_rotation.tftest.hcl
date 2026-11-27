mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "{\"active_key_name\":\"new\",\"legacy_key_name\":\"old\",\"keys\":{\"old\":{\"value\":\"legacy-key\"},\"new\":{\"value\":\"new-key\"}}}"
    }
  }
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

override_module {
  target = module.services_common
  outputs = {
    function_tools_secret_key             = "legacy-key"
    function_tools_secret_arn             = "arn:aws:secretsmanager:us-east-1:123456789012:secret:legacy"
    api_handler_role_arn                  = "arn:aws:iam::123456789012:role/bt-test-api"
    api_handler_role_name                 = "bt-test-api"
    api_security_group_id                 = "sg-11111111111111111"
    brainstore_instance_security_group_id = "sg-22222222222222222"
    brainstore_iam_role_name              = "bt-test-brainstore"
    brainstore_iam_role_arn               = "arn:aws:iam::123456789012:role/bt-test-brainstore"
    quarantine_invoke_role_arn            = "arn:aws:iam::123456789012:role/bt-test-quarantine-invoke"
    quarantine_function_role_arn          = "arn:aws:iam::123456789012:role/bt-test-quarantine"
    quarantine_lambda_security_group_id   = "sg-33333333333333333"
  }
}

variables {
  deployment_name        = "bt-test"
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  brainstore_license_key = "test-license"
}

run "legacy_defaults" {
  command = plan
  assert {
    condition     = local.function_secret_key == "legacy-key" && local.service_token_secret_key == "legacy-key"
    error_message = "Unset keyring inputs must preserve both legacy keys."
  }
}

run "function_keyring_preserves_legacy_service_tokens" {
  command = plan
  variables {
    function_secret_keys_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-keyring"
  }
  assert {
    condition = (
      local.function_secret_key == data.aws_secretsmanager_secret_version.function_secret_keys[0].secret_string && local.service_token_secret_key == "legacy-key" &&
      data.aws_secretsmanager_secret_version.function_secret_keys[0].secret_id == var.function_secret_keys_secret_arn &&
      data.aws_secretsmanager_secret_version.service_token_secret_keys[0].secret_id == module.services_common.function_tools_secret_arn
    )
    error_message = "A function keyring must not change the service-token key."
  }
}

run "service_token_keyring_preserves_legacy_function_secrets" {
  command = plan
  variables {
    service_token_secret_keys_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:service-keyring"
  }
  assert {
    condition = (
      local.service_token_secret_key == data.aws_secretsmanager_secret_version.service_token_secret_keys[0].secret_string && local.function_secret_key == "legacy-key" &&
      data.aws_secretsmanager_secret_version.service_token_secret_keys[0].secret_id == var.service_token_secret_keys_secret_arn &&
      data.aws_secretsmanager_secret_version.function_secret_keys[0].secret_id == module.services_common.function_tools_secret_arn
    )
    error_message = "A service-token keyring must not change the function key."
  }
}
