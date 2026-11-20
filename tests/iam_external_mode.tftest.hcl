# External IAM mode (create_iam = false): what it rejects, and how it checks that
# security owns the roles it looks up, and how the ownership marker fails a later
# change to create_iam.
#
# The lookups use the mock's role, which carries the customer owner tag. A run
# that needs a different tag, ARN or profile role overrides one lookup. A mocked
# plan can't see which AWS write permissions a stack needs, so
# scripts/check-external-mode-plan reads the plan that
# plans_external_mode_without_iam_writers emits and fails on any IAM writer.

mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  # An apply fills computed strings with random text, and the provider validates
  # some of them as ARNs.
  mock_data "aws_eks_cluster" {
    defaults = { identity = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE" }] }] }
  }
  mock_data "aws_secretsmanager_secret_versions" {
    defaults = {
      versions = [{ version_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", version_stages = ["AWSCURRENT"] }]
    }
  }
  mock_resource "aws_appautoscaling_policy" {
    defaults = { arn = "arn:aws:autoscaling:us-east-1:123456789012:scalingPolicy:00000000-0000-0000-0000-000000000000:resource/ecs/service/mock:policyName/mock" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/mock" }
  }
  mock_resource "aws_elasticache_cluster" {
    defaults = { cache_nodes = [{ id = "0001", address = "mock.cache.internal", port = 6379, availability_zone = "us-east-1a" }] }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = { arn = "arn:aws:iam::123456789012:instance-profile/mock" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000" }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock"
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock/invocations"
    }
  }
  mock_resource "aws_lambda_invocation" {
    defaults = { result = "{\"status\":\"complete\"}" }
  }
  mock_resource "aws_lambda_layer_version" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:layer:mock:1" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0", latest_version = 1 }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/mock/1234567890123456" }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/mock/1234567890123456/1234567890123456" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/1234567890123456" }
  }

  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock-bucket" }
  }

  mock_data "aws_iam_role" {
    defaults = {
      arn  = "arn:aws:iam::123456789012:role/mock"
      path = "/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }
  mock_data "aws_iam_instance_profile" {
    defaults = {
      arn      = "arn:aws:iam::123456789012:instance-profile/mock"
      path     = "/"
      role_arn = "arn:aws:iam::123456789012:role/mock"
    }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  deployment_name        = "bt-test"
  brainstore_license_key = "test-license"

  create_iam = false

  create_vpc                   = false
  existing_vpc_id              = "vpc-12345678"
  existing_private_subnet_1_id = "subnet-11111111"
  existing_private_subnet_2_id = "subnet-22222222"
  existing_private_subnet_3_id = "subnet-33333333"
  existing_public_subnet_1_id  = "subnet-44444444"

  enable_quarantine_vpc                   = true
  existing_quarantine_vpc_id              = "vpc-87654321"
  existing_quarantine_private_subnet_1_id = "subnet-55555555"
  existing_quarantine_private_subnet_2_id = "subnet-66666666"
  existing_quarantine_private_subnet_3_id = "subnet-77777777"
}

# The mock returns one role ARN for every lookup, and the KMS module wants the
# Auto Scaling service-linked role's ARN.
override_data {
  target = module.kms[0].data.aws_iam_role.autoscaling_service_linked_role
  values = { arn = "arn:aws:iam::123456789012:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling" }
}

# The two PrivateLink rejections below still plan the subnet lookups.
override_data {
  target = data.aws_subnet.quarantine_privatelink_main[0]
  values = { vpc_id = "vpc-12345678", availability_zone = "us-east-1a" }
}

override_data {
  target = data.aws_subnet.quarantine_privatelink_main[1]
  values = { vpc_id = "vpc-12345678", availability_zone = "us-east-1b" }
}

override_data {
  target = data.aws_subnet.quarantine_privatelink_main[2]
  values = { vpc_id = "vpc-12345678", availability_zone = "us-east-1c" }
}

override_data {
  target = data.aws_subnet.quarantine_privatelink_quarantine[0]
  values = { vpc_id = "vpc-87654321", availability_zone = "us-east-1a" }
}

override_data {
  target = data.aws_subnet.quarantine_privatelink_quarantine[1]
  values = { vpc_id = "vpc-87654321", availability_zone = "us-east-1b" }
}

override_data {
  target = data.aws_subnet.quarantine_privatelink_quarantine[2]
  values = { vpc_id = "vpc-87654321", availability_zone = "us-east-1c" }
}

run "plans_external_mode_without_iam_writers" {
  command = plan

  assert {
    condition     = terraform_data.iam_ownership_mode.input == false
    error_message = "External mode must create the ownership marker, recording create_iam = false."
  }

  assert {
    condition = (
      module.iam.api_handler_role_arn == "arn:aws:iam::123456789012:role/mock"
      && module.iam.brainstore_instance_profile_arn == "arn:aws:iam::123456789012:instance-profile/mock"
      && module.iam.db_monitoring_role_arn == "arn:aws:iam::123456789012:role/mock"
      && module.iam.ai_proxy_invoke_role_arn == null
    )
    error_message = "External mode must wire consumers to the looked-up roles and profile, and have no AIProxy invoke role."
  }
}

run "plans_greenfield_stack_with_customer_tagged_roles" {
  command = plan

  variables {
    override_iam_names = {
      "role.api_handler" = { name = "example-api", path = "/security/" }
    }
    existing_iam = {
      "role.gateway_task" = { arn = "arn:aws:iam::123456789012:role/security/example-gateway" }
    }
  }

  override_data {
    target = module.iam.data.aws_iam_role.external["api_handler"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/security/example-api"
      path = "/security/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  override_data {
    target = module.iam.data.aws_iam_role.external["gateway_task"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/security/example-gateway"
      path = "/security/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  assert {
    condition = (
      module.iam.api_handler_role_arn == "arn:aws:iam::123456789012:role/security/example-api"
      && module.iam.gateway_task_role_arn == "arn:aws:iam::123456789012:role/security/example-gateway"
    )
    error_message = "Sparse overrides and existing_iam references must reach the consumers."
  }
}

# Rejections. Each one names the input that the message tells the caller to change.

run "rejects_lambda_ingress_in_external_mode" {
  command = plan

  variables {
    enable_ecs_api = false
  }

  expect_failures = [var.create_iam]
}

run "rejects_lambda_ingress_in_standalone_call" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    region         = "us-east-1"
    account_id     = "123456789012"
    create_iam     = true
    iam_owner      = "customer"
    enable_ecs_api = false
  }

  expect_failures = [var.iam_owner]
}

run "rejects_external_eks_in_external_mode" {
  command = plan

  variables {
    use_deployment_mode_external_eks = true
  }

  expect_failures = [var.create_iam]
}

run "rejects_loop_runtime_in_external_mode" {
  command = plan

  variables {
    enable_loop_runtime = true
  }

  expect_failures = [var.create_iam]
}

run "rejects_remote_support_logs_in_external_mode" {
  command = plan

  variables {
    enable_braintrust_support_logs_access = true
  }

  expect_failures = [var.create_iam]
}

run "rejects_bastion_in_external_mode" {
  command = plan

  variables {
    enable_braintrust_support_shell_access = true
  }

  expect_failures = [var.create_iam]
}

run "rejects_flow_logs_in_external_mode" {
  command = plan

  variables {
    main_vpc_flow_log = {
      enabled          = true
      destination_type = "cloud-watch-logs"
    }
  }

  expect_failures = [var.create_iam]
}

run "rejects_managed_main_vpc_in_external_mode" {
  command = plan

  variables {
    create_vpc = true
  }

  expect_failures = [var.create_iam]
}

run "rejects_managed_quarantine_vpc_in_external_mode" {
  command = plan

  variables {
    existing_quarantine_vpc_id = null
  }

  expect_failures = [var.create_iam]
}

run "rejects_public_quarantine_privatelink_in_external_mode" {
  command = plan

  variables {
    use_private_gateway_quarantine_proxy = true
  }

  expect_failures = [var.create_iam]
}

run "rejects_private_quarantine_api_access_in_external_mode" {
  command = plan

  variables {
    enable_private_dataplane           = true
    create_quarantine_api_access       = true
    use_private_ai_gateway_origin      = false
    braintrust_api_alb_custom_domain   = "api.example.internal"
    braintrust_api_alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
  }

  expect_failures = [var.create_iam]
}

run "rejects_api_trust_override_in_external_mode" {
  command = plan

  variables {
    override_api_iam_role_trust_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }

  expect_failures = [var.create_iam]
}

run "rejects_brainstore_trust_override_in_external_mode" {
  command = plan

  variables {
    override_brainstore_iam_role_trust_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
  }

  expect_failures = [var.create_iam]
}

run "rejects_permissions_boundary_in_external_mode" {
  command = plan

  variables {
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/boundary"
  }

  expect_failures = [var.create_iam]
}

run "rejects_additional_service_policies_in_external_mode" {
  command = plan

  variables {
    service_additional_policy_arns = ["arn:aws:iam::123456789012:policy/extra"]
  }

  expect_failures = [var.create_iam]
}

run "rejects_additional_brainstore_policies_in_external_mode" {
  command = plan

  variables {
    brainstore_additional_policy_arns = ["arn:aws:iam::123456789012:policy/extra"]
  }

  expect_failures = [var.create_iam]
}

run "rejects_assume_role_arn_lists_in_external_mode" {
  command = plan

  variables {
    s3_export_assume_role_arns = ["arn:aws:iam::123456789012:role/export"]
  }

  expect_failures = [var.create_iam]
}

run "rejects_bedrock_assume_role_arns_in_external_mode" {
  command = plan

  variables {
    ai_gateway_bedrock_assume_role_arns = ["arn:aws:iam::123456789012:role/bedrock"]
  }

  expect_failures = [var.create_iam]
}

run "rejects_eks_trust_flags_in_external_mode" {
  command = plan

  variables {
    enable_eks_pod_identity = true
  }

  expect_failures = [var.create_iam]
}

run "rejects_eks_irsa_in_external_mode" {
  command = plan

  variables {
    enable_eks_irsa = true
  }

  expect_failures = [var.create_iam]
}

run "rejects_eks_cluster_arn_and_namespace_in_external_mode" {
  command = plan

  variables {
    existing_eks_cluster_arn = "arn:aws:eks:us-east-1:123456789012:cluster/example"
    eks_namespace            = "braintrust"
  }

  expect_failures = [var.create_iam]
}

# Ownership tag. A module-managed stack tags its IAM with braintrust, and a stack
# that skipped v7.3.0 has no tag at all. Either one would plan to destroy that IAM.
# These runs plan the module directly, because expect_failures can't name a
# lookup inside a child module.

run "rejects_role_tagged_braintrust" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    region     = "us-east-1"
    account_id = "123456789012"
  }

  override_data {
    target = data.aws_iam_role.external["api_handler"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
      path = "/"
      tags = { BraintrustIAMOwner = "braintrust" }
    }
  }

  expect_failures = [data.aws_iam_role.external["api_handler"]]
}

run "rejects_role_without_ownership_tag" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    region     = "us-east-1"
    account_id = "123456789012"
  }

  override_data {
    target = data.aws_iam_role.external["api_handler"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
      path = "/"
      tags = {}
    }
  }

  expect_failures = [data.aws_iam_role.external["api_handler"]]
}

run "rejects_role_with_unexpected_ownership_tag_value" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    region     = "us-east-1"
    account_id = "123456789012"
  }

  override_data {
    target = data.aws_iam_role.external["db_monitoring"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/bt-test-db-monitoring"
      path = "/"
      tags = { BraintrustIAMOwner = "someone-else" }
    }
  }

  expect_failures = [data.aws_iam_role.external["db_monitoring"]]
}

run "rejects_existing_iam_arn_for_a_braintrust_tagged_role" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    region     = "us-east-1"
    account_id = "123456789012"
    existing_iam = {
      "role.gateway_task" = { arn = "arn:aws:iam::123456789012:role/bt-test-gateway-task" }
    }
  }

  override_data {
    target = data.aws_iam_role.external["gateway_task"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/bt-test-gateway-task"
      path = "/"
      tags = { BraintrustIAMOwner = "braintrust" }
    }
  }

  expect_failures = [data.aws_iam_role.external["gateway_task"]]
}

run "rejects_instance_profile_without_a_role" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    region     = "us-east-1"
    account_id = "123456789012"
  }

  override_data {
    target = data.aws_iam_instance_profile.external[0]
    values = {
      arn      = "arn:aws:iam::123456789012:instance-profile/bt-test-brainstore-instance-profile"
      path     = "/"
      role_arn = ""
    }
  }

  expect_failures = [data.aws_iam_instance_profile.external[0]]
}

run "rejects_instance_profile_whose_role_is_not_the_brainstore_role" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    region     = "us-east-1"
    account_id = "123456789012"
  }

  override_data {
    target = data.aws_iam_instance_profile.external[0]
    values = {
      arn      = "arn:aws:iam::123456789012:instance-profile/bt-test-brainstore-instance-profile"
      path     = "/"
      role_arn = "arn:aws:iam::123456789012:role/bt-test-other-role"
    }
  }

  expect_failures = [data.aws_iam_instance_profile.external[0]]
}

# Ownership marker. A stack that has applied once can't change create_iam in either
# direction. A flip would otherwise plan to destroy every role the stack created, or
# try to create roles that security already owns. Each flip applies a stack and plans
# the other mode against the same state. The fixture is external-compatible, with
# supplied VPCs, no rejected feature, empty name maps and customer-tagged lookups,
# so the marker's postcondition is the only failure.

run "applies_a_managed_stack_with_the_ownership_marker" {
  command   = apply
  state_key = "marked_managed"

  variables {
    create_iam = true
  }

  assert {
    condition     = terraform_data.iam_ownership_mode.output == true
    error_message = "A managed stack must record create_iam = true in the ownership marker."
  }
}

run "rejects_flip_to_external_on_marked_stack" {
  command   = plan
  state_key = "marked_managed"

  expect_failures = [terraform_data.iam_ownership_mode]
}

run "applies_an_external_stack_with_the_ownership_marker" {
  command   = apply
  state_key = "marked_external"

  assert {
    condition     = terraform_data.iam_ownership_mode.output == false
    error_message = "An external stack must record create_iam = false in the ownership marker."
  }
}

run "rejects_flip_to_managed_on_marked_stack" {
  command   = plan
  state_key = "marked_external"

  variables {
    create_iam = true
  }

  expect_failures = [terraform_data.iam_ownership_mode]
}
