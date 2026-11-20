terraform {
  # 1.17 is the version that CI and mise.toml run. We didn't look for a lower
  # minimum, and child modules keep >= 1.10.0. See MIGRATION_V8.md.
  required_version = ">= 1.17.0"
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
