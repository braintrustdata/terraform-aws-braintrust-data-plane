terraform {
  # v1.9 is needed for variable validation features
  # v1.2 is needed for precondition checks
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# The kubernetes, helm, and random providers required by modules/eks-deploy
# are declared there, not here. Terraform aggregates provider requirements
# across all submodules in the source tree regardless of whether they're
# instantiated (count=0), so every consumer of this module must configure
# those providers at their root. For non-EKS deployments they can be
# empty/no-op — `provider "kubernetes" {}` and `provider "helm" { kubernetes {} }`
# are sufficient because count=0 means the underlying resources are never
# evaluated. See examples/braintrust-data-plane-eks/provider.tf for a full
# EKS-mode configuration.
