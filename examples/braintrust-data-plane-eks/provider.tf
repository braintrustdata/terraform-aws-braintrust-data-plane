# provider "aws" {
#   region = "<your AWS region>"
#
#   # Optional but recommended: restrict to a specific credential profile/account.
#   # profile             = "<your AWS credential profile>"
#   # allowed_account_ids = ["<your AWS account ID>"]
# }

# The kubernetes and helm providers need the EKS cluster endpoint, which is created
# by the braintrust module. On a fresh deployment, use a two-step apply:
#
#   Step 1: terraform apply -target=module.braintrust.module.eks[0]
#   Step 2: terraform apply
#
# After step 1 the cluster exists and the data sources below succeed.
locals {
  eks_cluster_name = "${var.deployment_name}-eks"
}

data "aws_region" "current" {}

data "aws_eks_cluster" "braintrust" {
  name = local.eks_cluster_name
}

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
