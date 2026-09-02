resource "aws_lambda_layer_version" "duckdb_node_api" {
  layer_name  = "${var.deployment_name}-duckdb-node-api"
  description = "DuckDB Node API dependencies for Braintrust Lambda functions"

  s3_bucket = local.lambda_s3_bucket
  s3_key    = local.lambda_versions["DuckDBNodeAPILayer"]

  compatible_architectures = ["arm64"]
  compatible_runtimes      = ["nodejs22.x", "nodejs24.x"]

  lifecycle {
    create_before_destroy = true
  }
}
