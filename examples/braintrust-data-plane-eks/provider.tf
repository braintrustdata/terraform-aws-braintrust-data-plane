# provider "aws" {
#   region = "<your AWS region>"
#
#   # Optional but recommended: restrict to a specific credential profile/account.
#   # profile             = "<your AWS credential profile>"
#   # allowed_account_ids = ["<your AWS account ID>"]
# }

# The kubernetes and helm providers need the EKS cluster endpoint, which is
# created by the braintrust module. On a fresh deployment, use a two-step apply:
#
#   Step 1: terraform apply -target=module.braintrust.module.eks_cluster[0]
#   Step 2: terraform apply
#
# Step 1 creates the cluster; step 2's plan can then resolve the
# data.aws_eks_cluster below. This is also when Auto Mode's NodeClass and
# NodePool CRDs become queryable, which kubernetes_manifest needs at plan
# time.
locals {
  # Must match `${deployment_name}-eks`, where deployment_name is the value
  # set in main.tf. Keep these in sync if you change deployment_name.
  eks_cluster_name = "braintrust-eks"
}

data "aws_eks_cluster" "braintrust" {
  name = local.eks_cluster_name
}

data "aws_eks_cluster_auth" "braintrust" {
  name = local.eks_cluster_name
}

# Static token from `aws_eks_cluster_auth` — valid for 15 minutes from the
# time the data source is refreshed. That's well beyond what step 2 of the
# two-step apply can take (helm_release's default timeout is 5 minutes, and
# all other in-cluster resources are near-instant under Auto Mode), so the
# token never expires mid-apply. Simpler than the `exec { aws eks get-token }`
# pattern and doesn't require the AWS CLI on the runner.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.braintrust.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.braintrust.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.braintrust.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.braintrust.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.braintrust.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.braintrust.token
  }
}
