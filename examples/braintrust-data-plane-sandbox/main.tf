# tflint-ignore-file: terraform_module_pinned_source

module "braintrust-data-plane" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # Append '?ref=<version_tag>' to lock to a specific version of the module.

  ### This example is configured for sandbox/evaluation deployments with smaller
  ### instance types and simplified infrastructure. See the production example
  ### (examples/braintrust-data-plane/) for production-sized defaults.

  # IMPORTANT: Each deployment in the same AWS account must have a unique name.
  # Use a short prefix + your name or identifier (max 18 characters).
  # Do not change this after deployment. RDS and S3 resources can not be renamed.
  deployment_name = "bt-sandbox"

  # Braintrust org to allow by name. For multi-org or ID-only access, use "*"
  # and set primary_org_name for service-token management.
  braintrust_org_name = "your-org-name"

  # Optional comma-separated org ID allowlist. If braintrust_org_name is
  # a specific name, that org is included in the allowlist.
  allowed_org_ids = ""

  ### Tagging
  # Recommended: tag resources with your name/team for identification in shared accounts.
  # custom_tags = {
  #   Owner = "Your Name"
  #   Team  = "Your Team"
  # }

  ### Postgres configuration
  postgres_instance_type = "db.r8g.large"

  # Smaller storage for sandbox
  postgres_storage_size     = 100
  postgres_max_storage_size = 500

  postgres_storage_type = "gp3"

  # gp3 volumes under 400GB receive baseline performance (3000 IOPS, 125 MiB/s). These match the baseline.
  postgres_storage_iops       = 3000
  postgres_storage_throughput = 125

  postgres_version                    = "15"
  postgres_auto_minor_version_upgrade = true

  # Disable deletion protection so `terraform destroy` works without manual intervention.
  # Do NOT set this in production.
  DANGER_disable_database_deletion_protection = true

  ### Brainstore configuration
  # The license key for the Brainstore instance. You can get this from the Braintrust UI in Settings > Data Plane.
  brainstore_license_key = var.brainstore_license_key

  # Single reader and writer, downsized for sandbox.
  # IMPORTANT: Brainstore requires instance types with local NVMe storage.
  # Compatible families include: c8gd, c5d, m5d, i3, i4i.
  # Generic families (t3, m5, c5) will fail — the instance has no local disk.
  brainstore_instance_count = 1
  brainstore_instance_type  = "c8gd.xlarge"

  brainstore_writer_instance_count = 1
  brainstore_writer_instance_type  = "c8gd.xlarge"

  # Disable fast readers to reduce costs in sandbox. Production deployments enable by default.
  brainstore_fast_reader_instance_count = 0

  ### WARNING: skip_pg_for_brainstore_objects is safe for fresh sandbox deployments
  ### but can cause data loss or downtime if applied incorrectly to existing
  ### production environments. It is a ONE-WAY operation that cannot be rolled
  ### back without downtime. See the upgrade guide before enabling in production.

  skip_pg_for_brainstore_objects = "all"

  # Disable the quarantine VPC to simplify the sandbox deployment.
  # This disables user-defined function execution (scorers, tools) but avoids
  # ~30 dynamically-created Lambda functions that complicate teardown.
  # Set to true if you need to test user-defined functions.
  enable_quarantine_vpc = false

  ### Redis configuration
  redis_instance_type = "cache.t4g.small"
  redis_version       = "7.0"

  # Only use this when instructed to by the Braintrust team.
  # use_global_ai_gateway_origin   = false
  # global_ai_gateway_origin_domain = "gateway.braintrust.dev"

  ### Network configuration
  # Defaults are fine for most sandbox deployments. Only change if you need to
  # peer with other VPCs and the default CIDRs conflict.
  # vpc_cidr            = "10.175.0.0/21"
  # quarantine_vpc_cidr = "10.175.8.0/21"

  ### S3 CORS configuration
  # Additional CORS origins for the code bundle and lambda responses buckets.
  # Use s3_additional_allowed_origins to apply the same origins to both buckets,
  # or set per-bucket vars to scope an origin to just one bucket. Values from all
  # three are merged. Supports wildcards in the domain name.
  # s3_additional_allowed_origins                  = ["https://app.example.com"]
  # s3_code_bundle_additional_allowed_origins      = []
  # s3_lambda_responses_additional_allowed_origins = []
}
