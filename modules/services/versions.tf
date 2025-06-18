terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # 5.82.0 is required for aws_cloudfront_vpc_origin
      version = ">= 5.82.0, < 6.0.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}
