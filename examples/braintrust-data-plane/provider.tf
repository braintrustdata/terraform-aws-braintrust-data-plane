provider "aws" {
  region = "<your AWS region>"
  # Optional, but recommended. Use a specific AWS credential profile for creating the Braintrust
  # resources. This helps prevent accidental changes in the wrong account.
  profile = "<your AWS credential profile>"
  # Optional, but recommended. Only allow running in a specific AWS account.
  # This is helpful for preventing accidental changes in the wrong account.
  allowed_account_ids = ["<your AWS account ID>"]
}
