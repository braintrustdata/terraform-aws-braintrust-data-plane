# tflint-ignore-file: terraform_module_pinned_source

locals {
  # This is primarily used for tagging and naming resources in your AWS account.
  # Do not change this after deployment. RDS and S3 resources can not be renamed.
  deployment_name = "braintrust"
}

module "braintrust-data-plane" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # Append '?ref=<version_tag>' to lock to a specific version of the module.

  deployment_name     = local.deployment_name
  braintrust_org_name = "" # Add your organization name from the Braintrust UI here

  ### Service Configuration
  # The maximum number of concurrent executions to reserve and constrain Braintrust lambdas to.
  # If you run Braintrust in a shared account you should set these to a reasonable limit to avoid
  # impacting other non-Braintrust Lambdas. AWS has a global shared limit of 1000 concurrent executions per account.
  # By default these are unlimited which is ideal for dedicated AWS account.
  # Recommended 100 to 1000 for production in a shared account.
  # api_handler_reserved_concurrent_executions = 100
  # ai_proxy_reserved_concurrent_executions    = 100

  # The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost.
  # api_handler_provisioned_concurrency   = 0

  ### Postgres configuration
  # The default is small for development and testing purposes. Recommended db.r8g.2xlarge for production.
  # postgres_instance_type                = "db.t4g.xlarge"

  # Storage size (in GB) for the RDS instance. Recommended 1000GB for production.
  # postgres_storage_size                 = 1000
  # Maximum storage size (in GB) to allow the RDS instance to auto-scale to.
  # postgres_max_storage_size             = 4000

  # Storage type for the RDS instance. Recommended io2 for large production deployments.
  # postgres_storage_type                 = "gp3"

  # Storage IOPS for the RDS instance. Only applicable if storage_type is io1, io2, or gp3.
  # Recommended 15000 for production. Default for gp3 is 3000.
  # postgres_storage_iops                 = null

  # Throughput for the RDS instance. Only applicable if storage_type is gp3.
  # Recommended 500 for production if you are using gp3. Leave blank for io1 or io2
  # postgres_storage_throughput           = null

  # PostgreSQL engine version for the RDS instance.
  # postgres_version                      = "15.7"

  # Automatic upgrades of PostgreSQL minor engine version.
  # If true, AWS will automatically upgrade the minor version of the PostgreSQL engine for you.
  # Note: Don't include the minor version in your postgres_version if you want to use this.
  # If false, you will need to manually upgrade the minor version of the PostgreSQL engine.
  # postgres_auto_minor_version_upgrade   = false

  # Multi-AZ RDS instance. Enabling increases cost but provides higher availability. Recommended for production environments.
  # postgres_multi_az                     = true

  ### Brainstore configuration
  # Enable Brainstore for faster analytics
  enable_brainstore = true

  # The license key for the Brainstore instance. You can get this from the Braintrust UI in Settings > API URL.
  brainstore_license_key = var.brainstore_license_key

  # The instance type to use for the Brainstore. Recommended Graviton instance type with 16GB of memory and a local SSD for cache data.
  # If you're using dedicated writer nodes, you can run a smaller instance type for the reader nodes.
  # Recommended for production deployments is c8gd.8xlarge.
  # brainstore_instance_type             = "c8gd.8xlarge"

  # The number of Brainstore instances to provision
  # brainstore_instance_count            = 1

  # Optional: The number of dedicated Brainstore writer nodes to create
  # brainstore_writer_instance_count      = 1
  # brainstore_writer_instance_type       = "c8gd.8xlarge"

  ### Redis configuration
  # Default is acceptable for small production deployments. Recommended cache.m7g.large for larger deployments.
  # redis_instance_type                   = "cache.t4g.small"

  # Redis engine version
  # redis_version                         = "7.0"

  ### Network configuration
  # CIDR block for the VPC. You might need to adjust this so it does not conflict with any
  # other VPC CIDR blocks you intend to peer with Braintrust
  # vpc_cidr                             = "10.175.0.0/21"

  # CIDR block for the Quarantined VPC. This is used to run user defined functions in an isolated environment.
  # quarantine_vpc_cidr                   = "10.175.8.0/21"

  ### Advanced configuration
  # List of origins to whitelist for CORS
  # whitelisted_origins                   = []

  # Custom domain name for the CloudFront distribution
  # custom_domain                       = null

  # ARN of the ACM certificate for the custom domain
  # custom_certificate_arn              = null

  # The maximum number of requests per user allowed in the time frame specified by outbound_rate_limit_window_minutes. Setting to 0 will disable rate limits
  # outbound_rate_limit_max_requests      = 0

  # The time frame in minutes over which rate per-user rate limits are accumulated
  # outbound_rate_limit_window_minutes    = 1

  ## Braintrust Support
  # Enable sharing of Cloudwatch logs with Braintrust staff
  # enable_braintrust_support_logs_access = true

  # Enable Bastion SSH access for Braintrust staff. This will create a bastion host and a security group that allows EC2 instance connect access from the Braintrust IAM Role.
  # enable_braintrust_support_shell_access = true
}
