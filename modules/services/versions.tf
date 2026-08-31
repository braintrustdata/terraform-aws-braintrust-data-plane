terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.23.0, < 7.0.0"
    }
    http = {
      source = "hashicorp/http"
      # 3.3.0 is the first release with the data source's retry block and
      # request_timeout_ms (used in modules/services/main.tf).
      version = "~> 3.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
