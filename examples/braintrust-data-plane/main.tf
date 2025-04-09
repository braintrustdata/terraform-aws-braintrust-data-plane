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

  ### Postgres configuration
  # The default is small for development and testing purposes. Recommended db.r8g.2xlarge for production.
  # postgres_instance_type                = "db.t4g.xlarge"

  # Storage size (in GB) for the RDS instance. Recommended 1000GB for production.
  # postgres_storage_size                 = 100

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

  # Multi-AZ RDS instance. Enabling increases cost but provides higher availability. Recommended for production environments.
  # postgres_multi_az                     = true

  ### Brainstore configuration
  # Enable Brainstore for faster analytics
  enable_brainstore = false

  # The license key for the Brainstore instance. You can get this from the Braintrust UI in Settings > API URL.
  brainstore_license_key = var.brainstore_license_key

  # The instance type to use for the Brainstore. Must be a Graviton instance type. Preferably with 16GB of memory and a local SSD for cache data.
  # The default value is for tiny deployments. Recommended for production deployments is c7gd.8xlarge.
  # brainstore_instance_type             = "c7gd.xlarge"

  # The number of Brainstore instances to provision
  # brainstore_instance_count            = 1


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
  # The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost.
  # api_handler_provisioned_concurrency   = 0

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

}
