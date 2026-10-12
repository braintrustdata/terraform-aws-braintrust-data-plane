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
    defaults = { arn = "arn:aws:eks:us-east-1:123456789012:cluster/bt-test-sandbox" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0", latest_version = 1 }
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
  deployment_name           = "bt-test"
  vpc_id                    = "vpc-0123456789abcdef0"
  private_subnet_ids        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
  ecs_cluster_name          = "bt-test"
  loop_runtime_service_name = "bt-test-loop-runtime"
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
      !aws_vpc_endpoint.secrets_manager.private_dns_enabled &&
      aws_vpc_security_group_ingress_rule.secrets_manager_from_system.referenced_security_group_id == aws_security_group.system.id &&
      aws_vpc_security_group_egress_rule.system_to_secrets_manager.referenced_security_group_id == aws_security_group.secrets_manager.id &&
      aws_lambda_function.release.environment[0].variables.AWS_ENDPOINT_URL_SECRETS_MANAGER == "https://vpce-secrets.example.internal" &&
      jsondecode(aws_vpc_endpoint.secrets_manager.policy).Statement[0].Principal.AWS == aws_iam_role.release.arn &&
      toset(jsondecode(aws_vpc_endpoint.secrets_manager.policy).Statement[0].Resource) == toset([aws_secretsmanager_secret.server_tls.arn, aws_secretsmanager_secret.client_tls.arn])
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
      yamldecode(aws_cloudformation_stack.release.template_body).Resources.Workers.DeletionPolicy == "Retain" &&
      yamldecode(aws_cloudformation_stack.release.template_body).Resources.Workers.UpdateReplacePolicy == "Retain" &&
      yamldecode(aws_cloudformation_stack.release.template_body).Resources.Workers.Properties.NodegroupName["Fn::Sub"] == "sandbox-$${WorkerRevision}" &&
      yamldecode(aws_cloudformation_stack.release.template_body).Resources.Release.Properties.NodeGroupName.Ref == "Workers"
    )
    error_message = "Worker replacement must create a new pool and retain occupied pools for controller draining."
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
      jsondecode(aws_iam_role_policy.controller.policy).Statement[0].Resource == "arn:aws:ecs:us-east-1:123456789012:service/bt-test/bt-test-loop-runtime" &&
      jsondecode(aws_iam_role_policy.release.policy).Statement[2].Condition.StringLike["aws:ResourceTag/braintrust:sandbox-stack"] == "arn:aws:cloudformation:us-east-1:123456789012:stack/bt-test-sandbox-service/*"
    )
    error_message = "TLS access, Loop service reads and node-pool updates must be scoped to this deployment."
  }
  assert {
    condition = (
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).workerNodeSelector["braintrust.io/worker-revision"] == aws_cloudformation_stack.release.parameters.WorkerRevision &&
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).loopRuntime.service == var.loop_runtime_service_name &&
      jsondecode(aws_cloudformation_stack.release.parameters.HelmValues).prewarmTemplates[0].policy.networking.type == "disabled" &&
      aws_lambda_function.tls.handler == "handler.tls_handler" &&
      output.endpoint == "https://nodes.bt-test.sandbox.internal:9400"
    )
    error_message = "The installed chart must target the current pool and provision restricted sandboxes with automatic TLS."
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
