# tflint-ignore-file: terraform_module_pinned_source

module "braintrust-data-plane" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # Append '?ref=<version_tag>' to lock to a specific version of the module.

  ### Examples below are shown with the module defaults. You do not have to uncomment them
  ### unless you want to change the default value.
  ### The default values are for production-sized deployments.

  # This is primarily used for tagging and naming resources in your AWS account.
  # Do not change this after deployment. RDS and S3 resources can not be renamed.
  deployment_name = "braintrust"

  # Braintrust org to allow by name. For multi-org or ID-only access, use "*"
  # and set primary_org_name for service-token management.
  braintrust_org_name = "your-org-name"

  # Required when braintrust_org_name is "*", or when it is unset/empty.
  primary_org_name = "your-org-name"

  # Optional comma-separated Braintrust Org ID allowlist (IDs, not org names).
  # Example: "00000000-0000-4000-8000-000000000001,00000000-0000-4000-8000-000000000002"
  # If braintrust_org_name is a specific name, include that org's ID here for forward compatibility.
  allowed_org_ids = ""

  ### Postgres configuration
  # Changing this will incur a short downtime.
  postgres_instance_type = "db.r8g.2xlarge"

  # Initial storage size (in GB) for the RDS instance.
  postgres_storage_size = 1000
  # Maximum storage size (in GB) to allow the RDS instance to auto-scale to.
  postgres_max_storage_size = 10000

  # Storage type for the RDS instance. Recommended io2 for large production deployments.
  postgres_storage_type = "gp3"

  # Storage IOPS for the RDS instance. Only applicable if storage_type is io1, io2, or gp3.
  # Recommended 15000 for production.
  postgres_storage_iops = 15000

  # Throughput for the RDS instance. Only applicable if storage_type is gp3.
  # Recommended 500 for production if you are using gp3. Leave blank for io1 or io2
  postgres_storage_throughput = 500

  # PostgreSQL engine version for the RDS instance.
  postgres_version = "15"

  # Automatic upgrades of PostgreSQL minor engine version.
  # If true, AWS will automatically upgrade the minor version of the PostgreSQL engine for you.
  # Note: Don't include the minor version in your postgres_version if you want to use this.
  # If false, you will need to manually upgrade the minor version of the PostgreSQL engine.
  postgres_auto_minor_version_upgrade = true

  # Multi-AZ RDS instance. Enabling increases cost but provides higher availability.
  # Recommended for critical production environments. Doubles the cost of the RDS instance.
  # postgres_multi_az                     = false

  ### Brainstore configuration
  # The license key for the Brainstore instance. You can get this from the Braintrust UI in Settings > API URL.
  brainstore_license_key = var.brainstore_license_key

  # The number of Brainstore reader instances to provision
  # Recommended Graviton instance type with 16GB of memory
  brainstore_instance_count = 2
  brainstore_instance_type  = "c8gd.4xlarge"

  # The number of Brainstore fast reader instances to provision
  # Recommended Graviton instance type with 16GB of memory
  brainstore_fast_reader_instance_count = 2
  brainstore_fast_reader_instance_type  = "c8gd.4xlarge"

  # The number of dedicated Brainstore writer nodes to create
  # Recommended Graviton instance type with 32GB of memory
  brainstore_writer_instance_count = 1
  brainstore_writer_instance_type  = "c8gd.8xlarge"

  ### Redis configuration

  # Default is acceptable for typical production deployments.
  redis_instance_type = "cache.r7g.large"

  # Redis engine version
  redis_version = "7.0"

  ### Tagging
  # Optionally add any custom AWS tags you want to apply to all resources created by the module
  #  custom_tags = {
  #    CustomTagKey = "SomeValue"
  #  }
  #

  ### Network configuration
  # WARNING: You should choose these values carefully after discussing with your networking team.
  # Changing them after the fact is not possible and will require a complete rebuild of your Braintrust deployment.

  # CIDR block for the VPC. The core Braintrust services will be deployed in this VPC.
  # You might need to adjust this so it does not conflict with any other VPC CIDR blocks you intend to peer with Braintrust.
  # vpc_cidr                             = "10.175.0.0/21"

  # CIDR block for the Quarantined VPC. This is used to run user defined functions in an isolated environment.
  # You might need to adjust this so it does not conflict with any other VPC CIDR blocks you intend to peer with Braintrust
  # quarantine_vpc_cidr                   = "10.175.8.0/21"


  ### Advanced configuration

  # The maximum number of concurrent executions to reserve and constrain Braintrust lambdas to.
  # If you run Braintrust in a dedicated account you can leave these at "-1" (unlimited).
  # If you run Braintrust in a shared account you should set these to a reasonable limit to avoid
  # impacting other non-Braintrust Lambdas. Recommended 100 to 1000 for production in a shared account.
  # api_handler_reserved_concurrent_executions = -1
  # ai_proxy_reserved_concurrent_executions    = -1

  # Only use this when instructed to by the Braintrust team.
  # use_global_ai_gateway_origin   = false
  # global_ai_gateway_origin_domain = "gateway.braintrust.dev"

  # Optional URL-security controls for externally supplied outbound HTTP URLs.
  # Leave unset to use the application default mode of "warn".
  # unsafe_url_request_mode  = "reject"
  # url_security_dns_servers = "1.1.1.1,8.8.8.8"
  # url_security_allow_cidrs = "10.0.0.0/8"

  # Uncomment these to set extra environment variables for the services.
  # Only use this when instructed to by the Braintrust team.
  # brainstore_extra_env_vars = {}
  #
  # brainstore_extra_env_vars_writer = {}
  #
  # service_extra_env_vars = {
  #   APIHandler               = {}
  #   AIProxy                  = {}
  #   BillingCron              = {}
  #   CatchupETL               = {}
  #   MigrateDatabaseFunction  = {}
  #   QuarantineWarmupFunction = {}
  #   AutomationCron           = {}
  # }


  ### S3 CORS configuration
  # Additional CORS origins for the code bundle and lambda responses buckets.
  # Use s3_additional_allowed_origins to apply the same origins to both buckets,
  # or set per-bucket vars to scope an origin to just one bucket. Values from all
  # three are merged. Supports wildcards in the domain name.
  # s3_additional_allowed_origins                  = ["https://app.example.com"]
  # s3_code_bundle_additional_allowed_origins      = []
  # s3_lambda_responses_additional_allowed_origins = []


  ### Braintrust Remote Support

  # Enable sharing of Cloudwatch logs with Braintrust staff
  # enable_braintrust_support_logs_access = true

  # Enable Bastion SSH access for Braintrust staff. This will create a bastion host and a security group that allows EC2 instance connect access from the Braintrust IAM Role.
  # enable_braintrust_support_shell_access = true
}
