# Every IAM role, managed policy and instance profile the module creates must
# carry BraintrustIAMOwner = "braintrust", and callers must not be able to
# override it. A root plan can't see child resources, so each run plans one
# module directly. Every module run sets a conflicting BraintrustIAMOwner caller
# tag plus an unrelated one: the module has no validation of its own, so this
# shows the merge order, and the unrelated tag must survive.
#
# The database module can't be planned on its own because its outputs are
# sensitive. scripts/check-iam-ownership-tags covers it, and every other IAM
# resource, from the source.
#
# The root runs at the bottom cover the custom_tags validation.

mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = {
        ImageArn            = "arn:aws:lambda:us-east-1:123456789012:microvm-image:bt-loop-bt-test"
        ImageVersion        = "1"
        NetworkConnectorArn = "arn:aws:lambda:us-east-1:123456789012:network-connector:bt-loop-bt-test-restricted-egress"
      }
    }
  }
  mock_resource "aws_vpc_endpoint" {
    defaults = {
      dns_entry = [
        {
          dns_name       = "vpce-0123456789abcdef0-abcdefgh.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com"
          hosted_zone_id = "Z7HUB22UULQXV"
        },
      ]
    }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-test-loop-egress/1111111111111111" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222" }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

run "tags_services_common_iam_with_braintrust_owner" {
  command = plan
  module { source = "./modules/services-common" }

  variables {
    deployment_name                = "bt-test"
    vpc_id                         = "vpc-12345678"
    kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
    database_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
    code_bundle_s3_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
    lambda_responses_s3_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
    enable_quarantine_vpc          = true
    quarantine_vpc_id              = "vpc-87654321"
    custom_tags                    = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.api_handler_role.tags,
        aws_iam_role.brainstore_role.tags,
        aws_iam_role.quarantine_invoke_role[0].tags,
        aws_iam_role.quarantine_function_role[0].tags,
        aws_iam_policy.api_handler_policy.tags,
        aws_iam_policy.api_handler_quarantine[0].tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the services-common roles and managed policies."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.api_handler_role.tags,
        aws_iam_role.brainstore_role.tags,
        aws_iam_role.quarantine_invoke_role[0].tags,
        aws_iam_role.quarantine_function_role[0].tags,
        aws_iam_policy.api_handler_policy.tags,
        aws_iam_policy.api_handler_quarantine[0].tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The services-common roles and managed policies must keep unrelated caller tags."
  }
}

run "tags_services_iam_with_braintrust_owner" {
  command = plan
  module { source = "./modules/services" }

  variables {
    braintrust_org_name         = "bt-test-org"
    deployment_name             = "bt-test"
    vpc_id                      = "vpc-12345678"
    service_subnet_ids          = ["subnet-11111111", "subnet-22222222"]
    postgres_username           = "bt"
    postgres_password           = "bt-password"
    postgres_host               = "db.example.internal"
    use_redis_replication_group = false
    redis_host                  = "redis.example.internal"
    redis_port                  = "6379"
    whitelisted_origins         = ["https://example.com"]
    code_bundle_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
    lambda_responses_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
    api_security_group_id       = "sg-12345678"
    api_handler_role_arn        = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
    function_tools_secret_key   = "test-secret-key"
    use_quarantine_vpc          = false
    custom_tags                 = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.default_role.tags,
        aws_iam_role.automation_cron_role.tags,
        aws_iam_role.billing_cron.tags,
        aws_iam_role.catchup_etl.tags,
        aws_iam_role.migrate_database.tags,
        aws_iam_policy.api_handler_lambda_policies.tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the services roles and managed policy."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.default_role.tags,
        aws_iam_role.automation_cron_role.tags,
        aws_iam_role.billing_cron.tags,
        aws_iam_role.catchup_etl.tags,
        aws_iam_role.migrate_database.tags,
        aws_iam_policy.api_handler_lambda_policies.tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The services roles and managed policy must keep unrelated caller tags."
  }
}

run "tags_services_quarantine_and_lambda_api_iam_with_braintrust_owner" {
  command = plan
  module { source = "./modules/services" }

  variables {
    braintrust_org_name            = "bt-test-org"
    deployment_name                = "bt-test"
    vpc_id                         = "vpc-12345678"
    service_subnet_ids             = ["subnet-11111111", "subnet-22222222"]
    postgres_username              = "bt"
    postgres_password              = "bt-password"
    postgres_host                  = "db.example.internal"
    use_redis_replication_group    = false
    redis_host                     = "redis.example.internal"
    redis_port                     = "6379"
    whitelisted_origins            = ["https://example.com"]
    code_bundle_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
    lambda_responses_bucket_arn    = "arn:aws:s3:::bt-test-lambda-responses"
    api_security_group_id          = "sg-12345678"
    api_handler_role_arn           = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
    function_tools_secret_key      = "test-secret-key"
    use_quarantine_vpc             = true
    quarantine_vpc_id              = "vpc-87654321"
    quarantine_vpc_private_subnets = ["subnet-44444444", "subnet-55555555", "subnet-66666666"]
    quarantine_function_role_arn   = "arn:aws:iam::123456789012:role/bt-test-QuarantineFunctionRole"
    lambda_version_tag_override    = "test-version"
    enable_quarantine_pruner       = true
    enable_ecs_api                 = false
    custom_tags                    = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.quarantine_pruner_role[0].tags,
        aws_iam_role.quarantine_warmup[0].tags,
        aws_iam_role.ai_proxy_invoke_role[0].tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the quarantine and AIProxy roles."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.quarantine_pruner_role[0].tags,
        aws_iam_role.quarantine_warmup[0].tags,
        aws_iam_role.ai_proxy_invoke_role[0].tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The quarantine and AIProxy roles must keep unrelated caller tags."
  }
}
run "tags_brainstore_instance_profile_with_braintrust_owner" {
  command = plan
  module { source = "./modules/brainstore-ec2" }

  variables {
    deployment_name                       = "bt-test"
    license_key_secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    license_key_secret_version            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    kms_key_arn                           = null
    vpc_id                                = "vpc-12345678"
    private_subnet_ids                    = ["subnet-12345678"]
    database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-test"
    database_host                         = "database.example.com"
    database_port                         = "5432"
    redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-redis-url"
    redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:token-test"
    braintrust_api_url                    = "http://api.example.internal:8000"
    ai_proxy_url_ssm_parameter            = "/bt-test/ai-proxy-url"
    brainstore_s3_bucket_arn              = "arn:aws:s3:::test-brainstore"
    lambda_responses_s3_bucket_arn        = "arn:aws:s3:::test-responses"
    code_bundle_s3_bucket_arn             = "arn:aws:s3:::test-code"
    brainstore_iam_role_name              = "bt-test-brainstore"
    brainstore_instance_security_group_id = "sg-12345678"
    writer_instance_count                 = 1
    fast_reader_instance_count            = 1
    custom_tags                           = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_instance_profile.brainstore.tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the Brainstore instance profile."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_instance_profile.brainstore.tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The Brainstore instance profile must keep unrelated caller tags."
  }
}

run "tags_brainstore_deployment_role_with_braintrust_owner" {
  command = plan
  module { source = "./modules/brainstore-deployment" }

  variables {
    deployment_name = "bt-test"
    version_tag     = "test-api-version"
    fleets = [{
      role                    = "reader"
      asg_name                = "bt-test-brainstore-123"
      launch_template_id      = "lt-abc123"
      launch_template_version = "2"
      desired_capacity        = 2
      target_group_arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/reader/abc123"
    }]
    custom_tags = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.waiter.tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the Brainstore deployment role."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.waiter.tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The Brainstore deployment role must keep unrelated caller tags."
  }
}

run "tags_vpc_flow_log_role_with_braintrust_owner" {
  command = plan
  module { source = "./modules/vpc" }

  variables {
    deployment_name       = "bt-test"
    vpc_name              = "main"
    vpc_cidr              = "10.175.0.0/21"
    public_subnet_1_cidr  = "10.175.0.0/24"
    public_subnet_1_az    = "us-east-1a"
    private_subnet_1_cidr = "10.175.1.0/24"
    private_subnet_1_az   = "us-east-1a"
    private_subnet_2_cidr = "10.175.2.0/24"
    private_subnet_2_az   = "us-east-1b"
    private_subnet_3_cidr = "10.175.3.0/24"
    private_subnet_3_az   = "us-east-1c"
    flow_log = {
      enabled          = true
      destination_type = "cloud-watch-logs"
    }
    custom_tags = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.flow_log[0].tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the managed Flow Logs role."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.flow_log[0].tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The managed Flow Logs role must keep unrelated caller tags."
  }
}

run "tags_remote_support_role_and_instance_profile_with_braintrust_owner" {
  command = plan
  module { source = "./modules/remote-support" }

  variables {
    deployment_name                        = "bt-test"
    vpc_id                                 = "vpc-12345678"
    public_subnet_ids                      = ["subnet-11111111"]
    private_subnet_ids                     = ["subnet-22222222", "subnet-33333333"]
    database_host                          = "db.example.internal"
    database_secret_arn                    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
    redis_url_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    redis_url_secret_version_id            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    kms_key_arn                            = "arn:aws:kms:us-east-1:123456789012:key/test"
    enable_braintrust_support_logs_access  = true
    enable_braintrust_support_shell_access = true
    custom_tags                            = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.braintrust_support[0].tags,
        aws_iam_role.bastion[0].tags,
        aws_iam_instance_profile.bastion[0].tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the support role, bastion role and bastion instance profile."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.braintrust_support[0].tags,
        aws_iam_role.bastion[0].tags,
        aws_iam_instance_profile.bastion[0].tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The support role, bastion role and bastion instance profile must keep unrelated caller tags."
  }
}

run "tags_api_ecs_execution_role_with_braintrust_owner" {
  command = plan
  module { source = "./modules/api-ecs" }

  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"

    deployment_name                       = "bt-test"
    kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/test"
    vpc_id                                = "vpc-0123456789abcdef0"
    private_subnet_ids                    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_cluster_arn                       = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
    ecs_cluster_name                      = "bt-test"
    braintrust_org_name                   = "test-org"
    database_url_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
    redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    brainstore_hostname                   = "brainstore.example.internal"
    brainstore_port                       = 9000
    response_bucket                       = "bt-test-responses"
    code_bundle_bucket                    = "bt-test-code"
    function_tools_secret_arn             = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
    whitelisted_origins                   = ["https://example.com"]
    outbound_rate_limit_window_minutes    = 1
    outbound_rate_limit_max_requests      = 100
    monitoring_telemetry                  = "true"
    disable_billing_telemetry_aggregation = false
    billing_telemetry_log_level           = "info"
    quarantine_proxy_url                  = ""
    task_role_arn                         = "arn:aws:iam::123456789012:role/api-task"
    task_security_group_id                = "sg-0123456789abcdef0"

    braintrust_api_cpu_autoscaling = {
      target_value       = 70
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_memory_autoscaling = {
      target_value       = 75
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_event_loop_utilization_autoscaling = {
      target_value       = 70
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_event_loop_delay_autoscaling = {
      evaluation_periods = 1
      period             = 60
      cooldown           = 60
      steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
    }
    braintrust_api_ingest_cpu_autoscaling = {
      target_value       = 70
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_ingest_memory_autoscaling = {
      target_value       = 75
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_ingest_event_loop_utilization_autoscaling = {
      target_value       = 70
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_ingest_event_loop_delay_autoscaling = {
      evaluation_periods = 1
      period             = 60
      cooldown           = 60
      steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
    }
    braintrust_api_background_cpu_autoscaling = {
      target_value       = 70
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_background_memory_autoscaling = {
      target_value       = 75
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_background_event_loop_utilization_autoscaling = {
      target_value       = 70
      scale_in_cooldown  = 60
      scale_out_cooldown = 60
    }
    braintrust_api_background_event_loop_delay_autoscaling = {
      evaluation_periods = 1
      period             = 60
      cooldown           = 60
      steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
    }
    custom_tags = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.task_execution.tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the API ECS execution role."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.task_execution.tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The API ECS execution role must keep unrelated caller tags."
  }
}

run "tags_gateway_ecs_roles_with_braintrust_owner" {
  command = plan
  module { source = "./modules/gateway-ecs" }

  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    deployment_name                   = "bt-test"
    kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/test"
    vpc_id                            = "vpc-0123456789abcdef0"
    private_subnet_ids                = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_cluster_arn                   = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
    ecs_cluster_name                  = "bt-test"
    container_image                   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/gateway:test"
    target_group_arn                  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/1234567890123456"
    alb_security_group_id             = "sg-0123456789abcdef2"
    gateway_http_listener_arn         = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
    gateway_url                       = "http://gateway.internal"
    redis_url_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    redis_url_secret_version_id       = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    redis_port                        = 6379
    redis_security_group_id           = "sg-0123456789abcdef1"
    internal_observability_enabled    = false
    custom_tags                       = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.task_execution.tags,
        aws_iam_role.task.tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the Gateway task roles."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.task_execution.tags,
        aws_iam_role.task.tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The Gateway task roles must keep unrelated caller tags."
  }
}

run "tags_loop_runtime_ecs_roles_with_braintrust_owner" {
  command = plan
  module { source = "./modules/loop-runtime-ecs" }

  variables {
    deployment_name                           = "bt-test"
    kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/test"
    vpc_id                                    = "vpc-0123456789abcdef0"
    private_subnet_ids                        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_cluster_arn                           = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
    ecs_cluster_name                          = "bt-test"
    container_image                           = "123456789012.dkr.ecr.us-east-1.amazonaws.com/loop-runtime:test"
    target_group_arn                          = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/loop-runtime/1234567890123456"
    alb_security_group_id                     = "sg-0123456789abcdef2"
    loop_runtime_http_listener_arn            = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/loop-runtime/1234567890123456/1234567890123456"
    database_url_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
    redis_url_secret_arn                      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    redis_url_secret_version_id               = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    function_tools_secret_arn                 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
    brainstore_s3_bucket_name                 = "bt-test-brainstore"
    brainstore_s3_bucket_arn                  = "arn:aws:s3:::bt-test-brainstore"
    code_bundle_bucket                        = "bt-test-code"
    code_bundle_bucket_arn                    = "arn:aws:s3:::bt-test-code"
    brainstore_reader_url                     = "http://brainstore.example.internal:9000"
    ai_proxy_url                              = "https://api.example.com/v1/proxy"
    braintrust_api_url                        = "https://api.example.com"
    internal_observability_enabled            = true
    internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
    internal_observability_env_name           = "test"
    sandbox_egress_gateway_target_group_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/loop-egress/1234567890123456"
    brainstore_license_key_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    brainstore_license_key_secret_version     = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    brainstore_license_key_kms_key_arn        = "arn:aws:kms:us-east-1:123456789012:key/license"
    custom_tags                               = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.task_execution.tags,
        aws_iam_role.task.tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the Loop runtime task roles."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.task_execution.tags,
        aws_iam_role.task.tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The Loop runtime task roles must keep unrelated caller tags."
  }
}

run "tags_loop_microvm_roles_with_braintrust_owner" {
  command = plan
  module { source = "./modules/loop-runtime-sandbox-aws-microvm" }

  variables {
    deployment_name             = "bt-test"
    microvm_version_tag         = "test"
    endpoint_vpc_id             = "vpc-11111111111111111"
    endpoint_subnet_ids         = ["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]
    runtime_security_group_id   = "sg-11111111111111111"
    enable_microvm_runtime_logs = true
    custom_tags                 = { Environment = "test", BraintrustIAMOwner = "customer" }
  }

  override_data {
    target = data.aws_subnet.egress_gateway_nlb[0]
    values = { availability_zone = "us-east-1a" }
  }
  override_data {
    target = data.aws_subnet.egress_gateway_nlb[1]
    values = { availability_zone = "us-east-1b" }
  }
  override_data {
    target = data.aws_subnet.egress_gateway_nlb[2]
    values = { availability_zone = "us-east-1c" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.network_connector_operator[0].tags,
        aws_iam_role.microvm_image_build.tags,
        aws_iam_role.microvm_execution[0].tags,
      ] : tags.BraintrustIAMOwner == "braintrust"
    ])
    error_message = "A caller tag must not override BraintrustIAMOwner on the MicroVM connector, image build and execution roles."
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.network_connector_operator[0].tags,
        aws_iam_role.microvm_image_build.tags,
        aws_iam_role.microvm_execution[0].tags,
      ] : tags.Environment == "test"
    ])
    error_message = "The MicroVM connector, image build and execution roles must keep unrelated caller tags."
  }
}

run "rejects_braintrust_iam_owner_in_custom_tags" {
  command = plan

  variables {
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    deployment_name        = "bt-test"
    brainstore_license_key = "test-license"
    enable_quarantine_vpc  = true
    custom_tags            = { BraintrustIAMOwner = "customer" }
  }

  expect_failures = [var.custom_tags]
}

run "rejects_braintrust_iam_owner_in_any_letter_case" {
  command = plan

  variables {
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    deployment_name        = "bt-test"
    brainstore_license_key = "test-license"
    enable_quarantine_vpc  = true
    custom_tags            = { braintrustiamowner = "customer" }
  }

  expect_failures = [var.custom_tags]
}

run "plans_with_null_custom_tags" {
  command = plan

  variables {
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    deployment_name        = "bt-test"
    brainstore_license_key = "test-license"
    enable_quarantine_vpc  = true
    custom_tags            = null
  }

  assert {
    condition     = length(var.custom_tags) == 0
    error_message = "A null custom_tags must fall back to an empty map, as it did before the reserved-key validation."
  }
}

run "accepts_custom_tags_without_braintrust_iam_owner" {
  command = plan

  variables {
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    deployment_name        = "bt-test"
    brainstore_license_key = "test-license"
    enable_quarantine_vpc  = true
    custom_tags            = { Environment = "test" }
  }

  assert {
    condition     = local.all_custom_tags.Environment == "test"
    error_message = "Caller tags other than BraintrustIAMOwner must pass through unchanged."
  }
}
