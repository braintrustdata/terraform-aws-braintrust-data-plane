# tflint-ignore-file: terraform_module_pinned_source

module "braintrust-data-plane" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # Append '?ref=<version_tag>' to lock to a specific version of the module.

  ### Private API ECS deployment
  # This mode does not create CloudFront, API Gateway, or the Lambda services
  # module. The internal API ECS ALB is the primary API endpoint.

  # This is primarily used for tagging and naming resources in your AWS account.
  # Do not change this after deployment. RDS and S3 resources can not be renamed.
  deployment_name = "braintrust"

  # Add your organization name from the Braintrust UI here.
  braintrust_org_name = ""

  use_deployment_mode_private_api_ecs = true

  # The private API endpoint users will configure in Braintrust.
  api_ecs_fqdn = "braintrust.internal.example.com"

  # By default, private API ECS mode creates the ACM certificate, DNS validation
  # records, and Route53 alias record. The hosted zone is derived from
  # api_ecs_fqdn by removing the first DNS label and must exist in this AWS
  # account.

  # Alternative: manage the certificate and DNS outside the module.
  #
  # api_ecs_acm_certificate_arn           = "arn:aws:acm:REGION:ACCOUNT:certificate/CERTIFICATE_ID"
  # api_ecs_create_acm_certificate        = false
  # api_ecs_manage_certificate_validation = false
  # api_ecs_create_dns_record             = false
  #
  # Alternative: let the module create the ACM certificate, but manage DNS
  # validation and the endpoint alias outside the module.
  #
  # api_ecs_create_acm_certificate        = true
  # api_ecs_manage_certificate_validation = false
  # api_ecs_create_dns_record             = false

  # Permit access from your private networks or from specific security groups.
  api_ecs_authorized_cidr_blocks = ["10.0.0.0/8"]
  # api_ecs_authorized_security_groups = {
  #   vpn = "sg-0123456789abcdef"
  # }

  # Private API ECS supports code execution. With the quarantine VPC enabled,
  # code runs in isolated quarantine Lambda functions. If you set
  # enable_quarantine_vpc = false, code execution runs in-process instead.

  ### Postgres configuration
  postgres_instance_type = "db.r8g.2xlarge"

  postgres_storage_size     = 1000
  postgres_max_storage_size = 10000
  postgres_storage_type     = "gp3"

  postgres_storage_iops       = 15000
  postgres_storage_throughput = 500

  postgres_version                    = "15"
  postgres_auto_minor_version_upgrade = true

  ### Brainstore configuration
  brainstore_license_key = var.brainstore_license_key

  brainstore_instance_count = 2
  brainstore_instance_type  = "c8gd.4xlarge"

  brainstore_fast_reader_instance_count = 2
  brainstore_fast_reader_instance_type  = "c8gd.4xlarge"

  brainstore_writer_instance_count = 1
  brainstore_writer_instance_type  = "c8gd.8xlarge"

  ### Redis configuration
  redis_instance_type = "cache.t4g.medium"
  redis_version       = "7.0"

  ### Network configuration
  # WARNING: Choose these CIDR blocks carefully with your networking team.
  # Changing them later requires rebuilding the deployment.
  #
  # vpc_cidr            = "10.175.0.0/21"
  # quarantine_vpc_cidr = "10.175.8.0/21"
}
