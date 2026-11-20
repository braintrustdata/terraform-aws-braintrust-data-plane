# OpenTofu reads this file instead of versions.tf, so it repeats the whole
# terraform block. Keep the provider constraints identical to versions.tf.
# `uv run scripts/check-versions-tofu` fails when they differ.
terraform {
  # OpenTofu numbers its releases separately from Terraform. 1.13 is the line
  # that this module is validated against in CI.
  required_version = ">= 1.13.0"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    aws = {
      source = "hashicorp/aws"
      # 6.69.0 breaks API Gateway PutRestApi (bufio.Scanner: token too long); fixed in 6.69.1.
      version = ">= 6.23.0, != 6.69.0, < 7.0.0"
    }
  }
}
