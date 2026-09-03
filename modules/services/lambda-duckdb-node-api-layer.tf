data "http" "duckdb_node_api_layer_version" {
  url = "https://${local.lambda_s3_bucket}.s3.${data.aws_region.current.region}.amazonaws.com/lambda/DuckDBNodeAPILayer/version-${local.lambda_version_tag}"

  retry {
    attempts     = 5
    min_delay_ms = 500
    max_delay_ms = 5000
  }
  request_timeout_ms = 10000

  lifecycle {
    postcondition {
      # Do not fall back to the legacy public layer: Lambda releases before the
      # Node API migration are incompatible with this module version.
      condition     = self.status_code < 400
      error_message = "Failed to fetch DuckDB Node API layer version for ${local.lambda_version_tag}: HTTP ${self.status_code}."
    }
  }
}

resource "aws_lambda_layer_version" "duckdb_node_api" {
  layer_name  = "${var.deployment_name}-duckdb-node-api"
  description = "DuckDB Node API dependencies for Braintrust Lambda functions"

  s3_bucket = local.lambda_s3_bucket
  s3_key    = trimspace(data.http.duckdb_node_api_layer_version.response_body)

  compatible_architectures = ["arm64"]
  compatible_runtimes      = ["nodejs22.x", "nodejs24.x"]

  lifecycle {
    create_before_destroy = true
  }
}
