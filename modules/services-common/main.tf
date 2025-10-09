locals {
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }

  # OIDC issuer URL for EKS cluster (if cluster is provided)
  eks_oidc_issuer_url = var.eks_cluster_arn != null ? data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer : null
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  count = var.eks_cluster_arn != null ? 1 : 0
  name  = split("/", var.eks_cluster_arn)[1]
}

# Function tools secret for encryption
resource "aws_secretsmanager_secret" "function_tools_secret" {
  name_prefix = "${var.deployment_name}/FunctionToolsSecret-"
  description = "Function environment variables encryption key"
  kms_key_id  = var.kms_key_arn
  tags        = local.common_tags
}

data "aws_secretsmanager_random_password" "function_tools_secret" {
  exclude_characters  = "\"'@/\\"
  exclude_punctuation = true
  password_length     = 32
}

resource "aws_secretsmanager_secret_version" "function_tools_secret" {
  secret_id     = aws_secretsmanager_secret.function_tools_secret.id
  secret_string = data.aws_secretsmanager_random_password.function_tools_secret.random_password

  lifecycle {
    ignore_changes = [secret_string]
  }
}
