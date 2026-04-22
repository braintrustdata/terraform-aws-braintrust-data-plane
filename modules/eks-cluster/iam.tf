locals {
  # oidc_provider is the issuer URL already stripped of https://
  eks_oidc_issuer = module.eks.oidc_provider

  # IRSA-only trust policies published as outputs so the parent module can
  # feed them into services_common as override_*_trust_policy. EKS mode uses
  # OIDC only — no lambda.amazonaws.com or ec2.amazonaws.com principals.
  api_iam_trust_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.eks_oidc_issuer}:sub" = "system:serviceaccount:${var.eks_namespace}:${var.api_service_account_name}"
          "${local.eks_oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  brainstore_iam_trust_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.eks_oidc_issuer}:sub" = "system:serviceaccount:${var.eks_namespace}:${var.brainstore_service_account_name}"
          "${local.eks_oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# IAM for the AWS Load Balancer Controller (IRSA).
# The actual Helm release of the controller lives in the eks-deploy submodule
# because it uses the kubernetes/helm providers.
resource "aws_iam_policy" "lb_controller" {
  name   = "${var.deployment_name}-lb-controller"
  policy = file("${path.module}/assets/aws-lb-controller-iam-policy.json")
  tags   = local.common_tags
}

resource "aws_iam_role" "lb_controller" {
  name = "${var.deployment_name}-lb-controller"

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.eks_oidc_issuer}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${local.eks_oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  permissions_boundary = var.permissions_boundary_arn
  tags                 = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}
