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
      # 6.69.0 breaks API Gateway PutRestApi (bufio.Scanner: token too long); fixed in 6.69.1.
      version = ">= 6.23.0, != 6.69.0, < 7.0.0"
    }
  }
}
