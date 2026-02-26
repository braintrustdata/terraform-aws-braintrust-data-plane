provider "aws" {
  region = "us-east-1" # Change this to your AWS region

  # Optional, but recommended. Use a specific AWS credential profile for creating the Braintrust
  # resources. This helps prevent accidental changes in the wrong account.
  # Uncomment and set one of your profiles: default, sandbox, or 982534393296_AdministratorAccess
  # profile = "default"

  # Optional, but recommended. Only allow running in a specific AWS account.
  # This is helpful for preventing accidental changes in the wrong account.
  # allowed_account_ids = ["<your AWS account ID>"]

  # Optionally, you can add default tags to all resources created by this module.
  # default_tags {
  #   tags = {
  #     YourCustomTag = "<your-custom-value>"
  #   }
  # }
}
