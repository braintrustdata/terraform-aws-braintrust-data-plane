# provider "aws" {
#   region = "<your AWS region>"
#
#   # Optional but recommended: restrict to a specific credential profile/account.
#   # profile             = "<your AWS credential profile>"
#   # allowed_account_ids = ["<your AWS account ID>"]
# }

# The kubernetes and helm providers need the EKS cluster endpoint, which
# is created by the braintrust module. On a fresh deployment, use a
# two-step apply — see main.tf for the step-1 target command. Step 2 is
# a plain `terraform apply`.
locals {
  # Derived from `local.deployment_name` in main.tf so there's only one
  # place to edit the deployment name.
  eks_cluster_name = "${local.deployment_name}-eks"
}

data "aws_region" "current" {}

data "aws_eks_cluster" "braintrust" {
  name = local.eks_cluster_name
}

# `exec` calls `aws eks get-token` on each API call, so the token is
# always fresh. The simpler `data.aws_eks_cluster_auth` static-token
# pattern mints a token at refresh time that expires after 15 minutes —
# which burns if the apply sits at the approval prompt or if the
# refresh-to-final-API-call window ever exceeds 15 min. `exec` requires
# the AWS CLI on the runner, which consumers of this module need anyway
# for `aws eks update-kubeconfig` to debug the cluster.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.braintrust.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.braintrust.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--region", data.aws_region.current.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.braintrust.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.braintrust.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--region", data.aws_region.current.region]
    }
  }
}
