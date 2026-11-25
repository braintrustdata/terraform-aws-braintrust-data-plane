mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = <<-YAML
      # Public release metadata subset used by the Sandbox Service lookup tests.
      # Artifact source: https://braintrust-cf-us-east-1.s3.amazonaws.com/braintrust-v2.24.0.yaml
      # Required installer capabilities are mocked independently of these pins.
      Outputs:
        SandboxServiceBootstrapCapabilities:
          Value: license-secret,nodegroup-cleanup
        SandboxServiceChartUrl:
          Value: https://braintrust-cf-us-east-1.s3.amazonaws.com/sandbox-service/062fbf5e1090e1f624eda6d6f9dfe7af05921e3d90a6405d330feb7866775ad2/sandbox-service-0.1.0.tgz
        SandboxServiceHelmValues:
          Value:
            Fn::Sub:
              - |
                {
                  "hostname": "nodes.$${AWS::StackName}.sandbox.internal",
                  "image": "public.ecr.aws/braintrust/sandbox-service:053f8aef2ad66bb17ef868e35e0c3f9263e05c93",
                  "prewarmTemplates": [{
                    "image": "public.ecr.aws/braintrust/codex-runtime@sha256:6d7c649f35f335377d48fadd9b251e4ad4987d03427cc9ea730b87024c0811b5",
                    "resources": {
                      "vcpu_count": $${LoopRuntimeSandboxVcpuCount},
                      "memory_mib": $${LoopRuntimeSandboxMemoryMiB}
                    }
                  }]
                }
              - {}
      Resources:
        SandboxServiceReleaseFunction:
          Properties:
            CodeUri: s3://braintrust-cf-us-east-1/e6f89a1994f5cb53a5ee7e0f7c5eea27
        SandboxServiceRelease:
          Properties:
            ProviderVersion: cf3f36db527625591bfc987f7f5fd35e0c8b1e0ce5c6ae17d57ba9e9124c3a19
      YAML
    }
  }
}

mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/sandbox-test" }
  }
  mock_resource "aws_eks_cluster" {
    defaults = {
      arn                   = "arn:aws:eks:us-east-1:123456789012:cluster/bt-test-sandbox"
      endpoint              = "https://eks.example.internal"
      certificate_authority = [{ data = "test-ca" }]
    }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0", latest_version = 1 }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-test-sandbox-eg/1111111111111111" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-sandbox-eg/2222222222222222" }
  }
  mock_resource "aws_vpc_endpoint" {
    defaults = {
      dns_entry = [{ dns_name = "vpce-secrets.example.internal", hosted_zone_id = "ZEXAMPLE" }]
    }
  }
  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = {
        ClientTlsSecretArn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:sandbox-client"
        NodeGroupName      = "sandbox-test-workers"
      }
    }
  }
}

variables {
  checkpoint_bucket_id                  = "bt-test-sandbox-checkpoints"
  checkpoint_bucket_arn                 = "arn:aws:s3:::bt-test-sandbox-checkpoints"
  brainstore_license_key_secret_arn     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  brainstore_license_key_secret_version = "license-version"
  version_tag                           = "v2.24.0"
  deployment_name                       = "bt-test"
  vpc_id                                = "vpc-0123456789abcdef0"
  private_subnet_ids                    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
  data_plane_subnet_ids                 = ["subnet-main-one", "subnet-main-two", "subnet-main-three"]
  authorized_security_groups = {
    "Loop Runtime" = "sg-0123456789abcdef0"
  }
  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/boundary"
  custom_tags              = { Example = "sandbox" }
}

run "private_cluster_and_safe_worker_release" {
  command = apply
  module {
    source = "./modules/sandbox-service"
  }

  assert {
    condition = (
      data.http.release.url == "https://braintrust-cf-us-east-1.s3.amazonaws.com/braintrust-${var.version_tag}.yaml" &&
      aws_lambda_function.tls.s3_key == "e6f89a1994f5cb53a5ee7e0f7c5eea27" &&
      aws_lambda_function.release.s3_key == aws_lambda_function.tls.s3_key &&
      aws_cloudformation_stack.release.parameters.ProviderVersion == "cf3f36db527625591bfc987f7f5fd35e0c8b1e0ce5c6ae17d57ba9e9124c3a19" &&
      aws_cloudformation_stack.release.parameters.ChartUrl == "https://braintrust-cf-us-east-1.s3.amazonaws.com/sandbox-service/062fbf5e1090e1f624eda6d6f9dfe7af05921e3d90a6405d330feb7866775ad2/sandbox-service-0.1.0.tgz" &&
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).image == "public.ecr.aws/braintrust/sandbox-service:053f8aef2ad66bb17ef868e35e0c3f9263e05c93" &&
      output.sandbox_image == "public.ecr.aws/braintrust/codex-runtime@sha256:6d7c649f35f335377d48fadd9b251e4ad4987d03427cc9ea730b87024c0811b5"
    )
    error_message = "The chart, worker image, guest and both bootstrap functions must come from the selected published release."
  }

  assert {
    condition = (
      aws_lb.egress_gateway.internal &&
      aws_lb.egress_gateway.load_balancer_type == "network" &&
      aws_vpc_security_group_ingress_rule.egress_gateway_from_workers.referenced_security_group_id == aws_security_group.workers.id &&
      aws_vpc_security_group_egress_rule.workers_to_egress_gateway.referenced_security_group_id == aws_security_group.egress_gateway.id &&
      aws_vpc_security_group_egress_rule.workers_to_egress_gateway.from_port == 4002 &&
      output.egress_gateway_target_group_arn == aws_lb_target_group.egress_gateway.arn
    )
    error_message = "Sandbox Service must provide its own private forward-proxy endpoint with worker-only ingress."
  }
  assert {
    condition = (
      !aws_vpc_endpoint.secrets_manager.private_dns_enabled &&
      aws_vpc_security_group_ingress_rule.secrets_manager_from_system.referenced_security_group_id == aws_security_group.system.id &&
      aws_vpc_security_group_egress_rule.system_to_secrets_manager.referenced_security_group_id == aws_security_group.secrets_manager.id &&
      aws_lambda_function.release.environment[0].variables.AWS_ENDPOINT_URL_SECRETS_MANAGER == "https://vpce-secrets.example.internal" &&
      jsondecode(aws_vpc_endpoint.secrets_manager.policy).Statement[0].Principal.AWS == aws_iam_role.release.arn &&
      toset(jsondecode(aws_vpc_endpoint.secrets_manager.policy).Statement[0].Resource) == toset([aws_secretsmanager_secret.server_tls.arn, aws_secretsmanager_secret.client_tls.arn, var.brainstore_license_key_secret_arn])
    )
    error_message = "The installer must reach only its TLS secrets through a private endpoint without changing existing VPC DNS."
  }
  assert {
    condition = (
      aws_eks_cluster.sandbox.vpc_config[0].endpoint_private_access &&
      !aws_eks_cluster.sandbox.vpc_config[0].endpoint_public_access &&
      !aws_eks_cluster.sandbox.access_config[0].bootstrap_cluster_creator_admin_permissions
    )
    error_message = "The Sandbox Service cluster must use a private endpoint and explicit IAM access."
  }
  assert {
    condition = (
      yamldecode(aws_cloudformation_stack.release.template_body).Resources.Workers.DeletionPolicy == "Delete" &&
      yamldecode(aws_cloudformation_stack.release.template_body).Resources.Workers.UpdateReplacePolicy == "Retain" &&
      yamldecode(aws_cloudformation_stack.release.template_body).Resources.Workers.Properties.NodegroupName["Fn::Sub"] == "sandbox-$${WorkerRevision}" &&
      yamldecode(aws_cloudformation_stack.release.template_body).Resources.Release.Properties.NodeGroupName["Fn::GetAtt"] == ["Workers", "NodegroupName"] &&
      yamldecode(aws_cloudformation_stack.release.template_body).Outputs.NodeGroupName.Value["Fn::GetAtt"] == ["Workers", "NodegroupName"]
    )
    error_message = "Worker replacement must retain occupied pools while stack deletion removes the current pool."
  }
  assert {
    condition = (
      toset(jsondecode(aws_iam_role_policy.release.policy).Statement[2].Action) == toset(["eks:DeleteNodegroup", "eks:UpdateNodegroupConfig"]) &&
      jsondecode(aws_iam_role_policy.release.policy).Statement[3].Action == "autoscaling:DescribeAutoScalingGroups" &&
      aws_lambda_function_event_invoke_config.release.maximum_event_age_in_seconds == 60 &&
      aws_lambda_function_event_invoke_config.tls.maximum_event_age_in_seconds == 60 &&
      length(aws_eks_access_entry.operator) == 0
    )
    error_message = "The installer needs scoped pool cleanup, autoscaling reads and no stale asynchronous retries; operator access is opt-in."
  }
  assert {
    condition = (
      aws_cloudformation_stack.release.parameters.LicenseKeySecretArn == var.brainstore_license_key_secret_arn &&
      aws_cloudformation_stack.release.parameters.LicenseKeySecretVersion == var.brainstore_license_key_secret_version &&
      !contains(keys(aws_cloudformation_stack.release.parameters), "LicenseKey") &&
      !contains(keys(yamldecode(aws_cloudformation_stack.release.template_body).Resources.Release.Properties), "LicenseKey") &&
      one([for env in jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).env : env if env.name == "BRAINSTORE_LICENSE_KEY"]).valueFrom.secretKeyRef.name == "sandbox-telemetry" &&
      one([for env in jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).env : env if env.name == "BRAINTRUST_ENV"]).value == "customer"
    )
    error_message = "Worker telemetry must use the deployment license through a Kubernetes Secret and never pass its value through Terraform."
  }
  assert {
    condition = (
      aws_launch_template.workers.cpu_options[0].nested_virtualization == "enabled" &&
      aws_launch_template.workers.metadata_options[0].http_tokens == "required" &&
      aws_launch_template.workers.metadata_options[0].http_put_response_hop_limit == 1 &&
      contains(aws_launch_template.workers.vpc_security_group_ids, aws_security_group.workers.id) &&
      !contains(aws_launch_template.workers.vpc_security_group_ids, aws_security_group.system.id)
    )
    error_message = "Workers need nested virtualization, protected instance metadata and a separate security group."
  }
  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.workers_from_authorized_security_groups["Loop Runtime"].referenced_security_group_id == "sg-0123456789abcdef0" &&
      aws_vpc_security_group_ingress_rule.workers_from_authorized_security_groups["Loop Runtime"].from_port == 9400 &&
      aws_vpc_security_group_egress_rule.nodes_to_cluster["workers"].referenced_security_group_id == aws_eks_cluster.sandbox.vpc_config[0].cluster_security_group_id &&
      aws_vpc_security_group_egress_rule.worker_dns["tcp"].referenced_security_group_id == aws_security_group.system.id &&
      alltrue([for cidr in ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "0.0.0.0/0"] : !contains(local.public_ipv4_cidrs, cidr)])
    )
    error_message = "Worker private access must be limited to the authorized callers, Kubernetes API and cluster DNS."
  }
  assert {
    condition = (
      length(aws_ec2_managed_prefix_list.public_ipv4["first"].entry) == 52 &&
      length(aws_ec2_managed_prefix_list.public_ipv4["second"].entry) == 51 &&
      aws_iam_role.nodes.permissions_boundary == var.permissions_boundary_arn &&
      aws_iam_role.release.permissions_boundary == var.permissions_boundary_arn &&
      aws_iam_role.tls.permissions_boundary == var.permissions_boundary_arn &&
      aws_lambda_function.release.tags.BraintrustDeploymentName == var.deployment_name &&
      aws_cloudwatch_log_group.cluster.tags.BraintrustDeploymentName == var.deployment_name &&
      one([for spec in aws_launch_template.workers.tag_specifications : spec.tags if spec.resource_type == "volume"]).BraintrustDeploymentName == var.deployment_name &&
      aws_route53_zone.sandbox.tags.Example == "sandbox"
    )
    error_message = "The service must stay within prefix-list SG quotas and preserve deployment tags and IAM boundaries."
  }
  assert {
    condition = (
      toset(jsondecode(aws_iam_role_policy.tls.policy).Statement[0].Resource) == toset([
        aws_secretsmanager_secret.tls_seed.arn,
        aws_secretsmanager_secret.server_tls.arn,
        aws_secretsmanager_secret.client_tls.arn,
      ]) &&
      aws_eks_pod_identity_association.filesystems.service_account == "sandbox-service" &&
      jsondecode(aws_iam_role_policy.filesystems.policy).Statement[1].Resource == "${var.checkpoint_bucket_arn}/sandbox-filesystems/*" &&
      jsondecode(aws_iam_role_policy.release.policy).Statement[2].Condition.StringLike["aws:ResourceTag/braintrust:sandbox-stack"] == "arn:aws:cloudformation:us-east-1:123456789012:stack/bt-test-sandbox-service/*"
    )
    error_message = "TLS access, Loop service reads and node-pool updates must be scoped to this deployment."
  }
  assert {
    condition = (
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).workerNodeSelector["braintrust.io/worker-revision"] == aws_cloudformation_stack.release.parameters.WorkerRevision &&
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).filesystemRetention &&
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).checkpointStore == output.checkpoint_store &&
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).workerNodeReaderGroup == "braintrust:sandbox-worker-node-readers" &&
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).prewarmTemplates[0].policy.networking.type == "disabled" &&
      aws_lambda_function.tls.handler == "handler.tls_handler" &&
      output.endpoint == "https://nodes.bt-test.sandbox.internal:9400"
    )
    error_message = "The installed chart must target the current pool and provision restricted sandboxes with automatic TLS."
  }
}

run "operator_access" {
  command = apply
  module {
    source = "./modules/sandbox-service"
  }
  variables {
    operator_role_arn                  = "arn:aws:iam::123456789012:role/sandbox-operator"
    brainstore_license_key_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/license"
    checkpoint_bucket_kms_key_arn      = "arn:aws:kms:us-east-1:123456789012:key/checkpoints"
    internal_observability_enabled     = true
    internal_observability_env_name    = "test"
    monitoring_telemetry               = ""
    authorized_security_groups = {
      "Operator" = "sg-operator"
    }
  }
  assert {
    condition = (
      aws_eks_access_entry.operator[0].principal_arn == var.operator_role_arn &&
      aws_eks_access_policy_association.operator[0].access_scope[0].type == "cluster" &&
      aws_vpc_security_group_ingress_rule.workers_from_authorized_security_groups["Operator"].from_port == 9400 &&
      aws_vpc_security_group_ingress_rule.cluster_from_authorized_security_groups["Operator"].from_port == 443
    )
    error_message = "Optional operators need private network and cluster access."
  }
  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role_policy.release.policy).Statement : statement if statement.Action == "kms:Decrypt"]).Resource == var.brainstore_license_key_kms_key_arn &&
      one([for statement in jsondecode(aws_iam_role_policy.release.policy).Statement : statement if statement.Action == "kms:Decrypt"]).Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com" &&
      jsondecode(aws_iam_role_policy.filesystems.policy).Statement[2].Resource == var.checkpoint_bucket_kms_key_arn &&
      jsondecode(aws_iam_role_policy.filesystems.policy).Statement[2].Condition.StringLike["kms:EncryptionContext:aws:s3:arn"] == [var.checkpoint_bucket_arn, "${var.checkpoint_bucket_arn}/sandbox-filesystems/*"] &&
      one([for env in local.helm_values.env : env if env.name == "BRAINTRUST_ENV"]).value == "test" &&
      one([for env in local.helm_values.env : env if env.name == "BRAINSTORE_PULSE_OBSERVABILITY_ONLY"]).value == "true" &&
      one([for env in local.helm_values.env : env if env.name == "BRAINSTORE_CONTROL_PLANE_TELEMETRY"]).value == ",metrics,traces"
    )
    error_message = "Encrypted checkpoint and license access must stay scoped to their keys and AWS services, while worker telemetry follows the existing deployment settings."
  }
}

run "rejects_subnet_in_another_vpc" {
  command = plan
  module {
    source = "./modules/sandbox-service"
  }
  override_data {
    target = data.aws_subnet.private["1"]
    values = { vpc_id = "vpc-other" }
  }
  expect_failures = [data.aws_subnet.private["1"]]
}

run "rejects_duplicate_subnets" {
  command = plan
  module {
    source = "./modules/sandbox-service"
  }
  variables {
    private_subnet_ids = ["subnet-one", "subnet-one", "subnet-three"]
  }
  expect_failures = [var.private_subnet_ids]
}

run "rejects_missing_subnet" {
  command = plan
  module {
    source = "./modules/sandbox-service"
  }
  variables {
    private_subnet_ids = ["subnet-one", "subnet-two", ""]
  }
  expect_failures = [var.private_subnet_ids]
}

run "rejects_unsupported_worker_type" {
  command = plan
  module {
    source = "./modules/sandbox-service"
  }
  variables {
    instance_types = ["t3.medium"]
  }
  expect_failures = [var.instance_types]
}

run "rejects_shared_application_subnet" {
  command = plan
  module {
    source = "./modules/sandbox-service"
  }
  variables {
    private_subnet_ids = ["subnet-main-one", "subnet-two", "subnet-three"]
  }
  expect_failures = [var.private_subnet_ids]
}

run "release_override_updates_the_whole_artifact_bundle" {
  command = apply
  module {
    source = "./modules/sandbox-service"
  }
  variables {
    version_tag = "v2.24.0-custom"
  }
  override_data {
    target = data.http.release
    values = {
      status_code   = 200
      response_body = <<-YAML
        Outputs:
          SandboxServiceBootstrapCapabilities:
            Value: license-secret,nodegroup-cleanup
          SandboxServiceChartUrl:
            Value: https://braintrust-cf-us-east-1.s3.amazonaws.com/sandbox-service/custom/chart.tgz
          SandboxServiceHelmValues:
            Value:
              Fn::Sub: '{"image":"public.ecr.aws/braintrust/sandbox-service:custom","prewarmTemplates":[{"image":"public.ecr.aws/braintrust/codex-runtime:custom"}]}'
        Resources:
          SandboxServiceReleaseFunction:
            Properties:
              CodeUri: s3://braintrust-cf-us-east-1/custom-bootstrap
          SandboxServiceRelease:
            Properties:
              ProviderVersion: custom-provider
      YAML
    }
  }
  assert {
    condition = (
      data.http.release.url == "https://braintrust-cf-us-east-1.s3.amazonaws.com/braintrust-v2.24.0-custom.yaml" &&
      aws_lambda_function.tls.s3_key == "custom-bootstrap" &&
      aws_lambda_function.release.s3_key == "custom-bootstrap" &&
      aws_cloudformation_stack.release.parameters.ProviderVersion == "custom-provider" &&
      aws_cloudformation_stack.release.parameters.ChartUrl == "https://braintrust-cf-us-east-1.s3.amazonaws.com/sandbox-service/custom/chart.tgz" &&
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).image == "public.ecr.aws/braintrust/sandbox-service:custom" &&
      output.sandbox_image == "public.ecr.aws/braintrust/codex-runtime:custom" &&
      output.chart_object_arn == "arn:aws:s3:::braintrust-cf-us-east-1/sandbox-service/custom/chart.tgz"
    )
    error_message = "A release override must update the worker, guest, chart, bootstrap and endpoint-policy object together."
  }
}

run "rejects_release_without_sandbox_artifacts" {
  command = plan
  module {
    source = "./modules/sandbox-service"
  }
  override_data {
    target = data.http.release
    values = { status_code = 200, response_body = "{}" }
  }
  expect_failures = [data.http.release]
}

run "rejects_installer_without_required_capabilities" {
  command = plan
  module {
    source = "./modules/sandbox-service"
  }
  override_data {
    target = data.http.release
    values = {
      status_code   = 200
      response_body = <<-YAML
        Outputs:
          SandboxServiceChartUrl:
            Value: https://braintrust-cf-us-east-1.s3.amazonaws.com/sandbox-service/old/chart.tgz
          SandboxServiceHelmValues:
            Value:
              Fn::Sub: '{"image":"public.ecr.aws/braintrust/sandbox-service:old","prewarmTemplates":[{"image":"public.ecr.aws/braintrust/codex-runtime:old"}]}'
        Resources:
          SandboxServiceReleaseFunction:
            Properties:
              CodeUri: s3://braintrust-cf-us-east-1/old-bootstrap
          SandboxServiceRelease:
            Properties:
              ProviderVersion: old-provider
        YAML
    }
  }
  expect_failures = [data.http.release]
}
