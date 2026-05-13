# provider "aws" {
#   region = "<your AWS region>"
#
#   # Optional but recommended.
#   # profile             = "<your AWS credential profile>"
#   # allowed_account_ids = ["<your AWS account ID>"]
# }

data "aws_region" "current" {}

provider "kubernetes" {
  host                   = module.braintrust.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.braintrust.eks_cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.braintrust.eks_cluster_name, "--region", data.aws_region.current.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.braintrust.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.braintrust.eks_cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.braintrust.eks_cluster_name, "--region", data.aws_region.current.region]
    }
  }
}
