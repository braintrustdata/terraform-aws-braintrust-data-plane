# tflint-ignore-file: terraform_module_pinned_source

# Example configuration for Braintrust data plane deployment using external EKS
# with Quarantine VPC enabled and EKS Pod Identity.
#
# This configuration:
# - Uses external EKS deployment mode (use_deployment_mode_external_eks = true)
# - Enables EKS Pod Identity (enable_eks_pod_identity = true)
# - Deploys the Quarantine VPC (enable_quarantine_vpc = true)
# - Deploys all IAM permissions needed for the Quarantine VPC

module "braintrust-data-plane" {
  # Using local source for testing - change to GitHub source for production
  source = "../../"
  # source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # Append '?ref=<version_tag>' to lock to a specific version of the module.

  # This is primarily used for tagging and naming resources in your AWS account.
  # Do not change this after deployment. RDS and S3 resources can not be renamed.
  deployment_name = "braintrust"

  # Add your organization name from the Braintrust UI here
  braintrust_org_name = "test-org"

  # Brainstore license key (required)
  brainstore_license_key = var.brainstore_license_key

  # Enable external EKS deployment mode
  # When true, disables lambdas, ec2, and ingress submodules.
  # It assumes an EKS deployment is being done outside of terraform.
  use_deployment_mode_external_eks = true

  # Enable EKS Pod Identity for the Braintrust IAM roles
  enable_eks_pod_identity = true

  # Optional: Specify your EKS cluster ARN to restrict the trust policy
  # existing_eks_cluster_arn = "arn:aws:eks:us-east-1:123456789012:cluster/my-cluster"

  # Optional: Specify the EKS namespace to restrict the trust policy
  # eks_namespace = "braintrust"

  # Enable the Quarantine VPC to run user defined functions in an isolated environment
  enable_quarantine_vpc = true

  # CIDR block for the Quarantined VPC
  # You might need to adjust this so it does not conflict with any other VPC CIDR blocks
  # quarantine_vpc_cidr = "10.175.8.0/21"

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
  # postgres_multi_az = false

  ### Redis configuration
  # Default is acceptable for typical production deployments.
  redis_instance_type = "cache.t4g.medium"

  # Redis engine version
  redis_version = "7.0"

  ### Network configuration
  # WARNING: You should choose these values carefully after discussing with your networking team.
  # Changing them after the fact is not possible and will require a complete rebuild of your Braintrust deployment.

  # CIDR block for the VPC. The core Braintrust services will be deployed in this VPC.
  # You might need to adjust this so it does not conflict with any other VPC CIDR blocks you intend to peer with Braintrust.
  # vpc_cidr = "10.175.0.0/21"

  ### Tagging
  # Optionally add any custom AWS tags you want to apply to all resources created by the module
  # custom_tags = {
  #   CustomTagKey = "SomeValue"
  # }
}
