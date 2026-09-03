# The first-party DuckDB layer and Lambda code must be selected atomically.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}
mock_provider "http" {}

variables {
  braintrust_org_name         = "test-org"
  primary_org_name            = "test-org"
  deployment_name             = "bt-test"
  brainstore_license_key      = "test-license"
  lambda_version_tag_override = "test-version"
}

override_data {
  target = module.services[0].data.http.lambda_versions
  values = {
    status_code   = 200
    response_body = "lambda/APIHandler/versions/a1b2c3.zip"
  }
}

run "duckdb_node_api_layer_plans" {
  command = plan

  override_data {
    target = module.services[0].data.http.duckdb_node_api_layer_version
    values = {
      status_code   = 200
      response_body = "lambda/DuckDBNodeAPILayer/versions/a1b2c3.zip"
    }
  }

  assert {
    condition     = length(module.services) == 1
    error_message = "the services module should be enabled for the DuckDB layer plan"
  }
}
