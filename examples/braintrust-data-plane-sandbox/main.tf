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

  # Add your organization name from the Braintrust UI here
  braintrust_org_name = ""

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


  # use_deployment_mode_private_api_ecs = true
  # api_ecs_dns_name                    = "jeff-aws-lambda-ecs-test"
  # api_ecs_route53_zone_name           = "sandbox.braintrust.dev"
  # api_ecs_create_dns_record           = true
  # api_ecs_create_acm_certificate      = true


  ### API ECS configuration
  # API ECS is disabled by default. To opt into the CloudFormation-compatible
  # API ECS path for eval/sandbox routes, uncomment:
  #
  # enable_api_ecs = true
  #
  # Brainstore can separately use API ECS for BRAINSTORE_AI_PROXY_URL:
  #
  # use_api_ecs_for_brainstore_ai_proxy_url = true
  #
  # For private-only sandbox testing, uncomment the private mode and provide
  # either an existing certificate ARN or managed certificate validation inputs.
  #
  # use_deployment_mode_private_api_ecs = true
  # api_ecs_acm_certificate_arn         = "arn:aws:acm:REGION:ACCOUNT:certificate/CERTIFICATE_ID"
  # api_ecs_dns_name                    = "api"

  ### Network configuration
  # Defaults are fine for most sandbox deployments. Only change if you need to
  # peer with other VPCs and the default CIDRs conflict.
  # vpc_cidr            = "10.175.0.0/21"
  # quarantine_vpc_cidr = "10.175.8.0/21"
}
