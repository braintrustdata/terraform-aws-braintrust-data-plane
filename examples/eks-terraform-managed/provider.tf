# provider "aws" {
#   region = "<your AWS region>"
#
#   # Optional but recommended.
#   # profile             = "<your AWS credential profile>"
#   # allowed_account_ids = ["<your AWS account ID>"]
# }

data "aws_region" "current" {}
