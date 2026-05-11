# provider "aws" {
#   region = "<your AWS region>"
#
#   # Optional but recommended: restrict to a specific credential profile/account.
#   # profile             = "<your AWS credential profile>"
#   # allowed_account_ids = ["<your AWS account ID>"]
# }

# The kubernetes and helm providers are configured from the braintrust
# module's cluster outputs (endpoint, CA data, name). Referencing these
# module outputs — rather than a `data.aws_eks_cluster` lookup — lets
# Terraform treat them as "known after apply" until the cluster is
# created, so the whole module can be brought up in a single
# `terraform apply`. No two-step targeting needed.
#
# `exec { aws eks get-token }` refreshes the bearer token on every API
# call, so long applies (cold image pulls, approval-prompt pauses) don't
# hit the 15-minute TTL of the simpler `aws_eks_cluster_auth` pattern.
# Requires the AWS CLI on the runner, which consumers of this module
# need anyway for `aws eks update-kubeconfig` to debug the cluster.

data "aws_region" "current" {}

provider "kubernetes" {
  host                   = module.braintrust-data-plane.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.braintrust-data-plane.eks_cluster_ca_certificate_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.braintrust-data-plane.eks_cluster_name, "--region", data.aws_region.current.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.braintrust-data-plane.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.braintrust-data-plane.eks_cluster_ca_certificate_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.braintrust-data-plane.eks_cluster_name, "--region", data.aws_region.current.region]
    }
  }
}
