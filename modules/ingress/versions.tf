terraform {
  # Cross-variable validation (enable_ecs_api vs the Lambda URL/ARN) needs 1.9+.
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.23.0, < 7.0.0"
    }
  }
}
