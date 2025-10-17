terraform {
  # v1.9 is needed for variable validation features
  # v1.2 is needed for precondition checks
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
