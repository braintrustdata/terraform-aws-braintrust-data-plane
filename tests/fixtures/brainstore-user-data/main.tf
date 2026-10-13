# Renders the Brainstore user_data template so tests can assert on the script.
# The launch template stores it gzipped, which test assertions cannot inspect.

terraform {
  required_version = ">= 1.10.0"
}

variable "datadog_agent_container_logs" {
  type = bool
}

variable "datadog_agent_otlp_env_vars" {
  type = map(string)
}

output "script" {
  value = templatefile("${path.module}/../../../modules/brainstore-ec2/templates/user_data.sh.tpl", {
    aws_region                      = "us-east-1"
    deployment_name                 = "bt-user-data"
    database_secret_arn             = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-user-data-database"
    database_host                   = "database.example.internal"
    database_port                   = "5432"
    redis_scheme                    = "redis"
    redis_host                      = "redis.example.internal"
    redis_port                      = "6379"
    brainstore_port                 = 4000
    brainstore_s3_bucket            = "bt-user-data-brainstore"
    lambda_responses_bucket_id      = "bt-user-data-lambda-responses"
    code_bundle_bucket_id           = "bt-user-data-code-bundles"
    brainstore_locks_s3_path        = "locks"
    brainstore_license_key          = "test-license"
    brainstore_version_override     = ""
    brainstore_release_version      = "v1"
    monitoring_telemetry            = "status,metrics,traces,logs"
    is_dedicated_reader_node        = "true"
    is_dedicated_writer_node        = "false"
    extra_env_vars                  = {}
    internal_observability_api_key  = "test-datadog-key"
    internal_observability_env_name = "test"
    internal_observability_region   = "us5"
    datadog_agent_container_logs    = var.datadog_agent_container_logs
    datadog_agent_otlp_env_vars     = var.datadog_agent_otlp_env_vars
    service_token_secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-user-data-service-token"
    custom_ca_bundle_secret_arn     = ""
    custom_post_install_script      = ""
    brainstore_cache_file_size      = "100gb"
    skip_pg_for_brainstore_objects  = ""
    ai_proxy_url_ssm_parameter      = "/bt-user-data/ai-proxy-url"
  })
}
