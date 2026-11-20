# Generation profiles for the Loop modules. See iam.tftest.hcl.
#
# The two runs apply different modules, so every override_data and
# override_resource block sits inside its run. loop_runtime_ecs attaches the
# policy that loop_microvm renders, so it runs second.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_data "aws_partition" {
    defaults = { partition = "aws-manifest", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }

  # A binding placeholder stands in for each value that AWS assigns at apply time.
  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = {
        ImageArn            = "$${binding:microvm_image_arn}"
        ImageVersion        = "1"
        NetworkConnectorArn = "$${binding:microvm_network_connector_arn}"
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
    defaults = { arn = "arn:aws-manifest:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-manifest-loop-egress/1111111111111111" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws-manifest:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-manifest-loop-egress/2222222222222222" }
  }

  # Apply mode materializes concrete values, and the provider validates many of
  # them as ARNs. These defaults only keep that validation happy. The roles get
  # their own through override_resource.
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws-manifest:iam::123456789012:role/manifest-unoverridden" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:manifest-unoverridden" }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

run "loop_microvm" {
  command = apply
  module { source = "./modules/loop-runtime-sandbox-aws-microvm" }

  variables {
    deployment_name             = "bt-manifest"
    microvm_version_tag         = "test"
    endpoint_vpc_id             = "vpc-11111111111111111"
    endpoint_subnet_ids         = ["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]
    runtime_security_group_id   = "sg-11111111111111111"
    enable_microvm_runtime_logs = true
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

  override_resource {
    target = aws_iam_role.network_connector_operator[0]
    values = {
      arn = "arn:aws-manifest:iam::123456789012:role/manifest-loop_runtime_sandbox_aws_microvm.network_connector_operator"
      id  = "manifest-loop_runtime_sandbox_aws_microvm.network_connector_operator"
    }
  }
  override_resource {
    target = aws_iam_role.microvm_image_build
    values = {
      arn = "arn:aws-manifest:iam::123456789012:role/manifest-loop_runtime_sandbox_aws_microvm.microvm_image_build"
      id  = "manifest-loop_runtime_sandbox_aws_microvm.microvm_image_build"
    }
  }
  override_resource {
    target = aws_iam_role.microvm_execution[0]
    values = {
      arn = "arn:aws-manifest:iam::123456789012:role/manifest-loop_runtime_sandbox_aws_microvm.microvm_execution"
      id  = "manifest-loop_runtime_sandbox_aws_microvm.microvm_execution"
    }
  }
  # Only the MicroVM endpoint carries a policy. Unset, the mock would fill in a
  # random string for this one.
  override_resource {
    target = aws_vpc_endpoint.egress_gateway
    values = {
      policy = null
      dns_entry = [
        {
          dns_name       = "vpce-0123456789abcdef0-abcdefgh.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com"
          hosted_zone_id = "Z7HUB22UULQXV"
        },
      ]
    }
  }
  override_resource {
    target = aws_cloudwatch_log_group.microvm_image
    values = { arn = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:manifest-loop_runtime_sandbox_aws_microvm-microvm_image" }
  }

  override_data {
    target = data.aws_iam_policy_document.microvm_build_assume_role
    values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.microvm_build_assume_role\"}" }
  }
  override_data {
    target = data.aws_iam_policy_document.network_connector_operator_assume_role
    values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.network_connector_operator_assume_role\"}" }
  }
  override_data {
    target = data.aws_iam_policy_document.microvm_image_build
    values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.microvm_image_build\"}" }
  }
  override_data {
    target = data.aws_iam_policy_document.microvm_execution_assume_role
    values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.microvm_execution_assume_role\"}" }
  }
}

run "loop_runtime_ecs" {
  command = apply
  module { source = "./modules/loop-runtime-ecs" }

  variables {
    deployment_name                         = "bt-manifest"
    kms_key_arn                             = "arn:aws-manifest:kms:us-east-1:123456789012:key/test"
    vpc_id                                  = "vpc-0123456789abcdef0"
    private_subnet_ids                      = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_cluster_arn                         = "arn:aws-manifest:ecs:us-east-1:123456789012:cluster/bt-manifest"
    ecs_cluster_name                        = "bt-manifest"
    container_image                         = "123456789012.dkr.ecr.us-east-1.amazonaws.com/loop-runtime:test"
    target_group_arn                        = "arn:aws-manifest:elasticloadbalancing:us-east-1:123456789012:targetgroup/loop-runtime/1234567890123456"
    alb_security_group_id                   = "sg-0123456789abcdef2"
    loop_runtime_http_listener_arn          = "arn:aws-manifest:elasticloadbalancing:us-east-1:123456789012:listener/app/loop-runtime/1234567890123456/1234567890123456"
    database_url_secret_arn                 = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:database"
    redis_url_secret_arn                    = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:redis"
    redis_url_secret_version_id             = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    function_tools_secret_arn               = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:function-tools"
    brainstore_s3_bucket_name               = "bt-manifest-brainstore"
    brainstore_s3_bucket_arn                = "arn:aws-manifest:s3:::bt-manifest-brainstore"
    code_bundle_bucket                      = "bt-manifest-code"
    code_bundle_bucket_arn                  = "arn:aws-manifest:s3:::bt-manifest-code"
    brainstore_reader_url                   = "http://brainstore.example.internal:9000"
    ai_proxy_url                            = "https://api.example.com/v1/proxy"
    braintrust_api_url                      = "https://api.example.com"
    sandbox_egress_gateway_target_group_arn = "arn:aws-manifest:elasticloadbalancing:us-east-1:123456789012:targetgroup/loop-egress/1234567890123456"
    brainstore_license_key_secret_arn       = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:license"
    brainstore_license_key_secret_version   = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    brainstore_license_key_kms_key_arn      = "arn:aws-manifest:kms:us-east-1:123456789012:key/license"
    enable_execute_command                  = true
    diagnostics_transcript_log_group_name   = "/braintrust-byoc/bt-manifest/diagnostics"
    additional_task_role_policy_json        = run.loop_microvm.task_role_policy_json
  }

  override_resource {
    target = aws_iam_role.task_execution
    values = {
      arn = "arn:aws-manifest:iam::123456789012:role/manifest-loop_runtime_ecs.task_execution"
      id  = "manifest-loop_runtime_ecs.task_execution"
    }
  }
  override_resource {
    target = aws_iam_role.task
    values = {
      arn = "arn:aws-manifest:iam::123456789012:role/manifest-loop_runtime_ecs.task"
      id  = "manifest-loop_runtime_ecs.task"
    }
  }

  override_data {
    target = data.aws_iam_policy_document.ecs_task_assume_role
    values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.ecs_task_assume_role\"}" }
  }
}
