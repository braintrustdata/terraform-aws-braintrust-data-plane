mock_provider "helm" {}

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
  mock_data "aws_iam_session_context" {
    defaults = { issuer_arn = "arn:aws:iam::123456789012:role/terraform-installer" }
  }
  mock_data "aws_secretsmanager_secret_versions" {
    defaults = { versions = [{ version_id = "tls-version-one", version_stages = ["AWSCURRENT"] }] }
  }
}

variables {
  deployment_name                           = "bt-test"
  server_tls_secret_arn                     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:sandbox-server"
  client_tls_secret_arn                     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:sandbox-client"
  tls_kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/tls-key"
  kubernetes_api_authorized_security_groups = { "Terraform runner" = "sg-installer" }
  vpc_id                                    = "vpc-0123456789abcdef0"
  private_subnet_ids                        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
  data_plane_subnet_ids                     = ["subnet-main-one", "subnet-main-two", "subnet-main-three"]
  authorized_security_groups = {
    "Loop Runtime" = "sg-0123456789abcdef0"
  }
  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/boundary"
  custom_tags              = { Example = "sandbox" }
}

run "private_cluster_and_native_worker_release" {
  command = apply
  module {
    source = "./modules/sandbox-service"
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
      yamldecode(helm_release.external_secrets.values[0]).extraEnv[0].value == "https://vpce-secrets.example.internal" &&
      jsondecode(aws_vpc_endpoint.secrets_manager.policy).Statement[0].Principal.AWS == aws_iam_role.tls.arn &&
      toset(jsondecode(aws_vpc_endpoint.secrets_manager.policy).Statement[0].Resource) == toset([var.server_tls_secret_arn, var.client_tls_secret_arn])
    )
    error_message = "The secrets controller must reach only its TLS secrets through a private endpoint without changing existing VPC DNS."
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
      aws_eks_node_group.workers.node_group_name == "sandbox-${local.worker_revision}" &&
      aws_eks_node_group.workers.launch_template[0].id == aws_launch_template.workers.id &&
      aws_eks_node_group.workers.labels["braintrust.io/worker-revision"] == local.worker_revision &&
      aws_eks_node_group.workers.scaling_config[0].min_size == 1 &&
      aws_eks_node_group.workers.scaling_config[0].max_size == 401 &&
      aws_eks_access_entry.installer.principal_arn == "arn:aws:iam::123456789012:role/terraform-installer" &&
      aws_vpc_security_group_ingress_rule.cluster_from_installers["Terraform runner"].from_port == 443 &&
      !contains(keys(aws_vpc_security_group_ingress_rule.workers_from_authorized_security_groups), "Terraform runner")
    )
    error_message = "Terraform must own the worker pool and grant the deployment runner only private API network access."
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
      aws_iam_role.tls.permissions_boundary == var.permissions_boundary_arn &&
      aws_eks_node_group.workers.tags.BraintrustDeploymentName == var.deployment_name &&
      aws_cloudwatch_log_group.cluster.tags.BraintrustDeploymentName == var.deployment_name &&
      one([for spec in aws_launch_template.workers.tag_specifications : spec.tags if spec.resource_type == "volume"]).BraintrustDeploymentName == var.deployment_name &&
      aws_route53_zone.sandbox.tags.Example == "sandbox"
    )
    error_message = "The service must stay within prefix-list SG quotas and preserve deployment tags and IAM boundaries."
  }
  assert {
    condition = (
      toset(jsondecode(aws_iam_role_policy.tls.policy).Statement[0].Resource) == toset([
        var.server_tls_secret_arn,
        var.client_tls_secret_arn,
      ]) &&
      aws_eks_pod_identity_association.filesystems.service_account == "sandbox-service" &&
      jsondecode(aws_iam_role_policy.filesystems.policy).Statement[1].Resource == "${aws_s3_bucket.filesystems.arn}/sandbox-filesystems/*" &&
      aws_s3_bucket_public_access_block.filesystems.block_public_policy &&
      !aws_s3_bucket.filesystems.force_destroy &&
      !contains(jsondecode(aws_iam_role_policy.tls.policy).Statement[0].Action, "secretsmanager:PutSecretValue") &&
      jsondecode(aws_iam_role_policy.tls.policy).Statement[1].Resource == var.tls_kms_key_arn &&
      aws_eks_pod_identity_association.tls.service_account == "sandbox-external-secrets"
    )
    error_message = "The secrets controller must read only the two supplied TLS bundles and their encryption key."
  }
  assert {
    condition = (
      yamldecode(helm_release.sandbox.values[0]).workerNodeSelector["braintrust.io/worker-revision"] == local.worker_revision &&
      yamldecode(helm_release.sandbox.values[0]).filesystemRetention &&
      yamldecode(helm_release.sandbox.values[0]).checkpointStore == output.checkpoint_store &&
      yamldecode(helm_release.sandbox.values[0]).workerNodeReaderGroup == "braintrust:sandbox-worker-node-readers" &&
      yamldecode(helm_release.sandbox.values[0]).prewarmTemplates[0].policy.networking.type == "disabled" &&
      yamldecode(helm_release.tls.values[0]).bundles.client.version == "tls-version-one" &&
      yamldecode(helm_release.external_secrets.values[0]).scopedRBAC &&
      helm_release.sandbox.disable_webhooks &&
      output.client_tls_secret_arn == var.client_tls_secret_arn &&
      output.endpoint == "https://nodes.bt-test.sandbox.internal:9400"
    )
    error_message = "Native Helm must target the current pool and consume pinned, existing TLS bundles without private key values."
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

run "tls_rotation_updates_only_bundle_revisions" {
  command = apply
  module {
    source = "./modules/sandbox-service"
  }
  override_data {
    target = data.aws_secretsmanager_secret_versions.tls["client"]
    values = { versions = [{ version_id = "tls-version-two", version_stages = ["AWSCURRENT"] }] }
  }
  assert {
    condition = (
      output.client_tls_secret_version == "tls-version-two" &&
      yamldecode(helm_release.tls.values[0]).bundles.client.version == "tls-version-two" &&
      yamldecode(helm_release.sandbox.values[0]).tlsRevision == sha256(jsonencode({ client = "tls-version-two", server = "tls-version-one" })) &&
      aws_eks_node_group.workers.labels["braintrust.io/worker-revision"] == local.worker_revision
    )
    error_message = "TLS rotation must pin the new bundle and update the chart revision without including private key values."
  }
}

run "rejects_empty_tls_secret" {
  command = plan
  module {
    source = "./modules/sandbox-service"
  }
  override_data {
    target = data.aws_secretsmanager_secret_versions.tls["server"]
    values = { versions = [] }
  }
  expect_failures = [data.aws_secretsmanager_secret_versions.tls["server"]]
}
