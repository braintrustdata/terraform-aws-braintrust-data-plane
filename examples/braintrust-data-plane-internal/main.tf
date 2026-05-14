# tflint-ignore-file: terraform_module_pinned_source

module "braintrust-data-plane" {
  # Using local source for in-repo testing. Change to the GitHub source when
  # copying this example outside of this repository.
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # Append '?ref=<version_tag>' to lock to a specific version of the module.

  ### Internal deployment
  # This example creates a Braintrust data plane whose primary API endpoint is
  # reachable only from private networks you authorize. It does not create the
  # standard public CloudFront/API Gateway ingress path.

  # IMPORTANT: Each deployment in the same AWS account must have a unique name.
  # Use a short prefix + your name or identifier (max 18 characters).
  # Do not change this after deployment. RDS and S3 resources can not be renamed.
  deployment_name = "braintrust"

  # Add your organization name from the Braintrust UI here.
  braintrust_org_name = ""

  ### Internal ingress configuration
  use_deployment_mode_private_api_ecs = true
  enable_api_ecs                      = true

  # The internal API endpoint users will configure in Braintrust.
  api_ecs_fqdn = "braintrust-api.internal.example.com"

  # By default, let the module create the ACM certificate, DNS validation
  # records, and the DNS alias for the internal load balancer. The hosted zone
  # is derived from api_ecs_fqdn by removing the first DNS label, and must exist in this AWS account.
  api_ecs_create_acm_certificate        = true
  api_ecs_manage_certificate_validation = true
  api_ecs_create_dns_record             = true

  # Alternative: manage the certificate and DNS outside the module. Use this
  # when you have a pre-provisioned ACM certificate, use ACM Private CA, manage
  # DNS validation in another account, or need private/split-horizon DNS.
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
  # For example: ["10.0.0.0/8", "172.16.0.0/12"].
  api_ecs_authorized_cidr_blocks = ["10.0.0.0/8"]
  # api_ecs_authorized_security_groups = {
  #   vpn = "sg-0123456789abcdef"
  # }

  # Brainstore should use the same internal API endpoint for AI proxy traffic.
  use_api_ecs_for_brainstore_ai_proxy_url = true

  # When using API ECS, code function execution is disabled by default. To run code functions inside the API ECS container, set `api_ecs_code_function_execution_mode = "api_ecs"`.
  api_ecs_code_function_execution_mode = "disabled"
  # Lambda quarantine execution for API ECS will be added in a future release.

  # API ECS desired count is managed by Application Auto Scaling. In private
  # mode, CPU and memory do not fully capture API load, so size api_ecs_min_count
  # as the steady number of API tasks needed to keep up with expected traffic.
  api_ecs_min_count           = 3
  api_ecs_max_count           = 3
  api_ecs_cpu_target_value    = 40
  api_ecs_memory_target_value = 50

  ### Postgres configuration
  postgres_instance_type = "db.r8g.2xlarge"

  postgres_storage_size     = 1000
  postgres_max_storage_size = 10000
  postgres_storage_type     = "gp3"

  postgres_storage_iops       = 15000
  postgres_storage_throughput = 500

  postgres_version                    = "17"
  postgres_auto_minor_version_upgrade = true

  ### Brainstore configuration
  # The license key for the Brainstore instance. You can get this from the
  # Braintrust UI in Settings > Data Plane.
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

  ### Tagging
  # Optionally add any custom AWS tags you want to apply to resources created by
  # the module.
  # custom_tags = {
  #   CustomTagKey = "SomeValue"
  # }

  ### Network configuration
  # WARNING: Choose these CIDR blocks carefully with your networking team.
  # Changing them later requires rebuilding the deployment.
  #
  # vpc_cidr            = "10.175.0.0/21"
  # quarantine_vpc_cidr = "10.175.8.0/21"
}
