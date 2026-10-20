terraform {
  # v1.9 is needed for variable validation features
  # v1.2 is needed for precondition checks
  required_version = ">= 1.10.0"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    aws = {
      source = "hashicorp/aws"
      # AWS provider 6.69.0's default trace logger scans HTTP bodies with a 64KB
      # bufio.Scanner and breaks API Gateway PutRestApi on the one-line OpenAPI body.
      # Lift this ceiling once that scanner fix is in a released provider.
      version = ">= 6.37.0, < 6.69.0"
    }
  }
}
