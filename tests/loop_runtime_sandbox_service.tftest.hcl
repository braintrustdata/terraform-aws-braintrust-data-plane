mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::123456789012:role/loop-test" } }
}

variables {
  sandbox_env_vars                              = { EXO_SANDBOX_PROVIDER = "aws-lambda-microvm", EXO_SANDBOX_IMAGE = "lambda-microvm" }
  deployment_name                               = "bt-test"
  kms_key_arn                                   = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  vpc_id                                        = "vpc-11111111111111111"
  private_subnet_ids                            = ["subnet-11111111111111111", "subnet-22222222222222222"]
  ecs_cluster_arn                               = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                              = "bt-test"
  container_image                               = "public.ecr.aws/braintrust/loop-runtime:test"
  target_group_arn                              = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop/1111111111111111"
  alb_security_group_id                         = "sg-11111111111111111"
  loop_runtime_http_listener_arn                = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-loop/1111111111111111/1111111111111111"
  sandbox_egress_gateway_target_group_arn       = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222"
  database_url_secret_arn                       = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn                          = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  redis_url_secret_version_id                   = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  function_tools_secret_arn                     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  brainstore_s3_bucket_name                     = "bt-test-brainstore"
  brainstore_s3_bucket_arn                      = "arn:aws:s3:::bt-test-brainstore"
  code_bundle_bucket                            = "bt-test-code-bundles"
  code_bundle_bucket_arn                        = "arn:aws:s3:::bt-test-code-bundles"
  brainstore_reader_url                         = "http://brainstore.internal:4000"
  ai_proxy_url                                  = "https://api.example.com/v1/proxy"
  braintrust_api_url                            = "https://api.example.com"
  internal_observability_enabled                = false
  internal_observability_api_key_secret_arn     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
  internal_observability_api_key_secret_version = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  brainstore_license_key_secret_arn             = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  internal_observability_env_name               = "test"
  internal_observability_region                 = "us5"
  monitoring_telemetry                          = "status,metrics,usage,memprof,traces,logs"
}

run "lambda_only_has_no_service_setup" {
  command = apply
  module {
    source = "./modules/loop-runtime-ecs"
  }
  assert {
    condition     = length(jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)) == 1 && length(aws_ecs_task_definition.loop_runtime.volume) == 0 && length(aws_eks_access_entry.sandbox_worker_nodes) == 0 && !contains(keys(local.merged_env_vars), "EXO_SANDBOX_SERVICE_DNS_URL")
    error_message = "Lambda-only tasks must retain their container and omit TLS and EKS access."
  }
}

run "service_uses_tls_private_egress_and_scoped_discovery" {
  command = apply
  module {
    source = "./modules/loop-runtime-ecs"
  }
  variables {
    sandbox_service = {
      endpoint                  = "https://nodes.bt-test.sandbox.internal:9400"
      image                     = "public.ecr.aws/braintrust/codex-runtime:test"
      egress_gateway_url        = "http://loop-egress.example.internal:4002"
      client_tls_secret_version = "tls-version-one"
      client_tls_kms_key_arn    = "arn:aws:kms:us-east-1:123456789012:key/tls-key"
      client_tls_secret_arn     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:sandbox-client"
      cluster_name              = "bt-test-sandbox"
      kubernetes_api_url        = "https://eks.example.internal"
      kubernetes_ca             = "test-ca"
      vcpu_count                = 1
      memory_mib                = 2048
    }
  }
  assert {
    condition = (
      contains(jsondecode(aws_iam_role_policy.task_execution_secrets.policy).Statement[1].Resource, var.sandbox_service.client_tls_kms_key_arn) &&
      jsondecode(aws_iam_role_policy.task_execution_secrets.policy).Statement[1].Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com"
    )
    error_message = "The ECS execution role must decrypt the supplied TLS key only through Secrets Manager."
  }

  assert {
    condition     = local.merged_env_vars.EXO_SANDBOX_SERVICE_IMAGE == var.sandbox_service.image && local.merged_env_vars.LOOP_RUNTIME_SANDBOX_SERVICE_EGRESS_GATEWAY_URL == var.sandbox_service.egress_gateway_url && local.merged_env_vars.LOOP_RUNTIME_SANDBOX_KUBERNETES_API_URL == var.sandbox_service.kubernetes_api_url && local.merged_env_vars.LOOP_RUNTIME_SANDBOX_EKS_CLUSTER == var.sandbox_service.cluster_name && local.merged_env_vars.EXO_SANDBOX_PROVIDER == "sandbox_service" && local.merged_env_vars.LOOP_RUNTIME_SANDBOX_FORWARD_PROXY_LISTEN == "0.0.0.0:4002" && length(aws_iam_role_policy.sandbox) == 0
    error_message = "Service connections must use private discovery and egress with explicit backend selection."
  }
  assert {
    condition     = length(aws_ecs_task_definition.loop_runtime.volume) == 1 && one(local.loop_runtime_container_definition.mountPoints).readOnly && contains(local.loop_runtime_container_definition.dependsOn, { containerName = "sandbox-tls-init", condition = "SUCCESS" }) && local.sandbox_tls_init_containers[0].secrets == [{ name = "TLS_BUNDLE", valueFrom = "${var.sandbox_service.client_tls_secret_arn}:::tls-version-one" }] && !contains(keys(local.merged_env_vars), "TLS_BUNDLE") && contains(jsondecode(aws_iam_role_policy.task_execution_secrets.policy).Statement[0].Resource, var.sandbox_service.client_tls_secret_arn)
    error_message = "The runtime must wait for secret-backed TLS files without storing the TLS bundle in the environment."
  }
  assert {
    condition     = aws_eks_access_entry.sandbox_worker_nodes[0].kubernetes_groups == toset(["braintrust:sandbox-worker-node-readers"]) && aws_eks_access_entry.sandbox_worker_nodes[0].cluster_name == var.sandbox_service.cluster_name && aws_ecs_task_definition.loop_runtime.task_role_arn == aws_eks_access_entry.sandbox_worker_nodes[0].principal_arn
    error_message = "ECS must wait for its scoped Kubernetes node-reader identity."
  }
}

run "legacy_backend_can_be_selected_with_fresh_sandboxes" {
  command = apply
  module {
    source = "./modules/loop-runtime-ecs"
  }
  assert {
    condition     = local.merged_env_vars.EXO_SANDBOX_PROVIDER == "aws-lambda-microvm" && length(aws_ecs_task_definition.loop_runtime.volume) == 0 && length(aws_eks_access_entry.sandbox_worker_nodes) == 0 && !contains(keys(local.merged_env_vars), "EXO_SANDBOX_SERVICE_DNS_URL")
    error_message = "Selecting the legacy backend must omit service TLS and discovery configuration."
  }
}
