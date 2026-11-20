# tflint-ignore-file: terraform_module_pinned_source

# Braintrust data plane in external IAM mode. Your security team creates every
# IAM role and the Brainstore instance profile by running modules/iam on its own.
# This configuration looks them up by name and deploys everything else.
#
# External IAM mode is for new stacks only. Once a stack has applied, create_iam
# can't change in either direction. See MIGRATION_V8.md and this example's README.

module "braintrust-data-plane" {
  # Using local source for testing - change to GitHub source for production
  source = "../../"
  # source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # Append '?ref=<version_tag>' to lock to a specific version of the module.

  # Do not create IAM. The module looks up the roles and the instance profile that
  # your security team created, and fails the plan unless each one is tagged
  # BraintrustIAMOwner = customer.
  create_iam = false

  # With create_iam = false the module also writes no S3 bucket policies and no Lambda
  # permissions. Your security team applies the TLS-only bucket policies.

  # By default the module looks up the default names, which come from deployment_name.
  # Pass the same override_iam_names to modules/iam when your security team runs it.
  # An entry changes only the fields it lists.
  # override_iam_names = {
  #   "role.api_handler" = { name = "example-api", path = "/security/" }
  # }

  # Use an exact reference when name lookup can't find a role. The module reads
  # it back and applies the same ownership check.
  # existing_iam = {
  #   "role.gateway_task" = { arn = "arn:aws:iam::123456789012:role/security/example-gateway" }
  # }

  # This is primarily used for tagging and naming resources in your AWS account.
  # Do not change this after deployment. RDS and S3 resources can not be renamed.
  deployment_name = "braintrust"

  # Braintrust org to allow by name. For multi-org or ID-only access, use "*"
  # and set primary_org_name for service-token management.
  braintrust_org_name = "your-org-name"

  # Required when braintrust_org_name is "*", or when it is unset/empty.
  primary_org_name = "your-org-name"

  # Optional comma-separated Braintrust Org ID allowlist (IDs, not org names).
  allowed_org_ids = ""

  # External IAM mode needs ECS ingress.
  enable_ecs_api = true

  # External IAM mode needs supplied networks. It rejects a module-managed VPC.
  # Your security team scopes the quarantine function policies to this VPC ID.
  create_vpc                   = false
  existing_vpc_id              = "vpc-11111111111111111"
  existing_private_subnet_1_id = "subnet-11111111111111111"
  existing_private_subnet_2_id = "subnet-22222222222222222"
  existing_private_subnet_3_id = "subnet-33333333333333333"
  existing_public_subnet_1_id  = "subnet-77777777777777777"

  enable_quarantine_vpc                   = true
  existing_quarantine_vpc_id              = "vpc-22222222222222222"
  existing_quarantine_private_subnet_1_id = "subnet-44444444444444444"
  existing_quarantine_private_subnet_2_id = "subnet-55555555555555555"
  existing_quarantine_private_subnet_3_id = "subnet-66666666666666666"

  # Optionally use a KMS key that you create. The module creates and then never
  # changes its own key otherwise. Your security team scopes the roles by key
  # alias, alias/braintrust/<deployment_name>, so it can create them first.
  # kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"

  # Capacity. These are the production-sized defaults.
  postgres_instance_type = "db.r8g.2xlarge"
  postgres_storage_size  = 1000
  redis_instance_type    = "cache.r7g.large"

  # External IAM mode rejects several features and inputs, such as trust overrides,
  # permissions boundaries and additional policy ARNs. See MIGRATION_V8.md for the list.

  ### Tagging
  # Do not set BraintrustIAMOwner. The module reserves it.
  # custom_tags = {
  #   CustomTagKey = "SomeValue"
  # }

  ### Brainstore configuration
  # The module uses the supplied secret object or stores the license value in a new
  # secret. Your security team scopes the secret by name, <deployment_name>/brainstore/license-key,
  # or by exact ARN when you supply an existing secret. The license key is available
  # under Settings > Data Plane in the Braintrust UI.
  brainstore_license_key                 = var.brainstore_license_key
  existing_brainstore_license_key_secret = var.existing_brainstore_license_key_secret
}
