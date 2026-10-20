# The published installer runs inside the private VPC. It writes TLS bundles
# directly to Secrets Manager; Terraform stores only their ARNs.
resource "aws_secretsmanager_secret" "tls_seed" {
  name_prefix = "${var.deployment_name}-sandbox-tls-seed-"
  description = "Persistent Sandbox Service TLS bootstrap material"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret" "server_tls" {
  name_prefix = "${var.deployment_name}-sandbox-server-tls-"
  description = "Sandbox worker server TLS bundle"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret" "client_tls" {
  name_prefix = "${var.deployment_name}-sandbox-client-tls-"
  description = "Sandbox client TLS bundle"
  tags        = local.common_tags
}

resource "aws_iam_role" "tls" {
  name                 = "${var.deployment_name}-sandbox-tls"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "tls_logs" {
  role       = aws_iam_role.tls.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "tls" {
  name = "sandbox-tls-bundles"
  role = aws_iam_role.tls.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue"]
      Resource = [aws_secretsmanager_secret.tls_seed.arn, aws_secretsmanager_secret.server_tls.arn, aws_secretsmanager_secret.client_tls.arn]
    }]
  })
}

resource "aws_iam_role" "release" {
  name                 = "${var.deployment_name}-sandbox-release"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "release_vpc" {
  role       = aws_iam_role.release.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "release" {
  name = "sandbox-release"
  role = aws_iam_role.release.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["eks:DescribeCluster", "eks:ListNodegroups"], Resource = aws_eks_cluster.sandbox.arn },
      {
        Effect   = "Allow"
        Action   = "eks:DescribeNodegroup"
        Resource = "arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:nodegroup/${local.cluster_name}/*"
      },
      {
        Effect    = "Allow"
        Action    = "eks:UpdateNodegroupConfig"
        Resource  = "arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:nodegroup/${local.cluster_name}/sandbox-*/*"
        Condition = { StringLike = { "aws:ResourceTag/braintrust:sandbox-stack" = local.stack_arn_pattern } }
      },
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = [aws_secretsmanager_secret.server_tls.arn, aws_secretsmanager_secret.client_tls.arn]
      },
    ]
  })
}

resource "aws_eks_access_entry" "release" {
  cluster_name  = aws_eks_cluster.sandbox.name
  principal_arn = aws_iam_role.release.arn
  type          = "STANDARD"
  tags          = local.common_tags
}

resource "aws_eks_access_policy_association" "release" {
  cluster_name  = aws_eks_cluster.sandbox.name
  principal_arn = aws_eks_access_entry.release.principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

resource "aws_cloudwatch_log_group" "tls" {
  name              = "/aws/lambda/${var.deployment_name}-sandbox-tls"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "release" {
  name              = "/aws/lambda/${var.deployment_name}-sandbox-release"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "tls" {
  function_name                  = "${var.deployment_name}-sandbox-tls"
  s3_bucket                      = local.artifact_bucket
  s3_key                         = local.versions["bootstrap-key"]
  source_code_hash               = local.versions["bootstrap-code-hash"]
  role                           = aws_iam_role.tls.arn
  runtime                        = "python3.13"
  handler                        = "handler.tls_handler"
  architectures                  = ["x86_64"]
  memory_size                    = 256
  timeout                        = 60
  reserved_concurrent_executions = 1
  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.tls.name
  }
  tags       = local.common_tags
  depends_on = [aws_iam_role_policy.tls, aws_iam_role_policy_attachment.tls_logs]
}

resource "aws_lambda_function" "release" {
  function_name                  = "${var.deployment_name}-sandbox-release"
  s3_bucket                      = local.artifact_bucket
  s3_key                         = local.versions["bootstrap-key"]
  source_code_hash               = local.versions["bootstrap-code-hash"]
  role                           = aws_iam_role.release.arn
  runtime                        = "python3.13"
  handler                        = "handler.handler"
  architectures                  = ["x86_64"]
  memory_size                    = 256
  timeout                        = 300
  reserved_concurrent_executions = 1
  environment {
    variables = {
      AWS_ENDPOINT_URL_SECRETS_MANAGER = "https://${aws_vpc_endpoint.secrets_manager.dns_entry[0].dns_name}"
    }
  }
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.system.id, aws_security_group.public_egress.id]
  }
  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.release.name
  }
  tags       = local.common_tags
  depends_on = [aws_iam_role_policy.release, aws_iam_role_policy_attachment.release_vpc]
}

resource "aws_lambda_function_event_invoke_config" "tls" {
  function_name          = aws_lambda_function.tls.function_name
  maximum_retry_attempts = 0
}

resource "aws_lambda_function_event_invoke_config" "release" {
  function_name          = aws_lambda_function.release.function_name
  maximum_retry_attempts = 0
}

# CloudFormation retains replaced worker pools while the chart drains their
# sandboxes. A Terraform node-group replacement would delete an occupied pool.
# RetainExceptOnCreate deletes a pool only when the operation that created it
# rolls back, so a failed install does not leave its name taken.
# The same stack owns the release so retained pools carry its exact StackId.
resource "aws_cloudformation_stack" "release" {
  name = local.stack_name
  parameters = {
    ClusterName        = aws_eks_cluster.sandbox.name
    NodeRoleArn        = aws_iam_role.nodes.arn
    SubnetIds          = join(",", var.private_subnet_ids)
    InstanceTypes      = join(",", var.instance_types)
    LaunchTemplateId   = aws_launch_template.workers.id
    LaunchVersion      = tostring(aws_launch_template.workers.latest_version)
    WorkerRevision     = local.worker_revision
    TlsFunctionArn     = aws_lambda_function.tls.arn
    ReleaseFunctionArn = aws_lambda_function.release.arn
    SeedSecretArn      = aws_secretsmanager_secret.tls_seed.arn
    ServerTlsSecretArn = aws_secretsmanager_secret.server_tls.arn
    ClientTlsSecretArn = aws_secretsmanager_secret.client_tls.arn
    Hostname           = local.hostname
    ChartUrl           = "https://${local.artifact_bucket}.s3.amazonaws.com/${local.versions["chart-key"]}"
    HelmValues         = jsonencode(local.helm_values)
    ProviderVersion    = local.versions["bootstrap-sha256"]
  }
  template_body = yamlencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Parameters = {
      ClusterName        = { Type = "String" }
      NodeRoleArn        = { Type = "String" }
      SubnetIds          = { Type = "CommaDelimitedList" }
      InstanceTypes      = { Type = "CommaDelimitedList" }
      LaunchTemplateId   = { Type = "String" }
      LaunchVersion      = { Type = "String" }
      WorkerRevision     = { Type = "String" }
      TlsFunctionArn     = { Type = "String" }
      ReleaseFunctionArn = { Type = "String" }
      SeedSecretArn      = { Type = "String" }
      ServerTlsSecretArn = { Type = "String" }
      ClientTlsSecretArn = { Type = "String" }
      Hostname           = { Type = "String" }
      ChartUrl           = { Type = "String" }
      HelmValues         = { Type = "String" }
      ProviderVersion    = { Type = "String" }
    }
    Resources = {
      Workers = {
        Type                = "AWS::EKS::Nodegroup"
        DeletionPolicy      = "RetainExceptOnCreate"
        UpdateReplacePolicy = "Retain"
        Properties = {
          ClusterName   = { Ref = "ClusterName" }
          NodegroupName = { "Fn::Sub" = "sandbox-$${WorkerRevision}" }
          NodeRole      = { Ref = "NodeRoleArn" }
          Subnets       = { Ref = "SubnetIds" }
          AmiType       = "AL2023_x86_64_STANDARD"
          InstanceTypes = { Ref = "InstanceTypes" }
          LaunchTemplate = {
            Id = { Ref = "LaunchTemplateId" }, Version = { Ref = "LaunchVersion" }
          }
          Labels = {
            "braintrust.io/workload"        = "sandbox-service"
            "braintrust.io/worker-revision" = { Ref = "WorkerRevision" }
          }
          Taints             = [{ Key = "braintrust.io/sandbox", Value = "true", Effect = "NO_SCHEDULE" }]
          ScalingConfig      = { MinSize = 1, MaxSize = 401, DesiredSize = 1 }
          UpdateConfig       = { MaxUnavailable = 1 }
          ForceUpdateEnabled = false
          NodeRepairConfig   = { Enabled = false }
          Tags               = merge(local.common_tags, { "braintrust:sandbox-stack" = { Ref = "AWS::StackId" } })
        }
      }
      Tls = {
        Type = "Custom::SandboxServiceTls"
        Properties = {
          ServiceToken       = { Ref = "TlsFunctionArn" }
          ServiceTimeout     = 90
          Hostname           = { Ref = "Hostname" }
          SeedSecretArn      = { Ref = "SeedSecretArn" }
          ServerTlsSecretArn = { Ref = "ServerTlsSecretArn" }
          ClientTlsSecretArn = { Ref = "ClientTlsSecretArn" }
          ProviderVersion    = { Ref = "ProviderVersion" }
        }
      }
      Release = {
        Type = "Custom::SandboxServiceRelease"
        Properties = {
          ServiceToken   = { Ref = "ReleaseFunctionArn" }
          ServiceTimeout = 360
          ClusterName    = { Ref = "ClusterName" }
          # Ref returns cluster/name; the installer needs only the group name.
          NodeGroupName      = { "Fn::GetAtt" = ["Workers", "NodegroupName"] }
          ChartUrl           = { Ref = "ChartUrl" }
          HelmValues         = { Ref = "HelmValues" }
          ServerTlsSecretArn = { "Fn::GetAtt" = ["Tls", "ServerTlsSecretArn"] }
          ClientTlsSecretArn = { "Fn::GetAtt" = ["Tls", "ClientTlsSecretArn"] }
          ProviderVersion    = { Ref = "ProviderVersion" }
        }
      }
    }
    Outputs = {
      ClientTlsSecretArn = { Value = { "Fn::GetAtt" = ["Tls", "ClientTlsSecretArn"] } }
      NodeGroupName      = { Value = { "Fn::GetAtt" = ["Workers", "NodegroupName"] } }
    }
  })
  tags = local.common_tags
  depends_on = [
    aws_eks_access_policy_association.release,
    aws_eks_pod_identity_association.dns,
    aws_eks_pod_identity_association.autoscaler,
    aws_eks_pod_identity_association.controller,
    aws_iam_role_policy.dns,
    aws_iam_role_policy.autoscaler,
    aws_iam_role_policy.controller,
    aws_iam_role_policy_attachment.nodes,
    aws_iam_role_policy.cni,
    aws_lambda_function_event_invoke_config.tls,
    aws_lambda_function_event_invoke_config.release,
    aws_vpc_security_group_ingress_rule.cluster_from_nodes,
    aws_vpc_security_group_ingress_rule.system_dns,
    aws_vpc_security_group_egress_rule.system_dns,
    aws_vpc_security_group_egress_rule.worker_dns,
    aws_vpc_security_group_ingress_rule.workers_from_controller,
    aws_vpc_security_group_egress_rule.controller_to_workers,
    aws_vpc_security_group_egress_rule.nodes_to_cluster,
    aws_vpc_security_group_egress_rule.system_public,
    aws_vpc_security_group_egress_rule.workers_public,
    aws_vpc_security_group_egress_rule.additional_public,
    aws_vpc_security_group_ingress_rule.secrets_manager_from_system,
    aws_vpc_security_group_egress_rule.system_to_secrets_manager,
  ]
}
