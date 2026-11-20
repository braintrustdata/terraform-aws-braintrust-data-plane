# OpenTofu reads this file instead of versions.tf, so it repeats the whole
# terraform block. Keep the provider constraints identical to versions.tf.
terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.23.0, < 7.0.0"
    }
  }
}
