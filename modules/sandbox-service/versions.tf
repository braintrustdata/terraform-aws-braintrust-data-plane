terraform {
  required_version = ">= 1.10.0"
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.37.0, < 7.0.0"
    }
  }
}
