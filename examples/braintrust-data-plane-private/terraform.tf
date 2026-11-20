# Example storing terraform state in S3.
# terraform {
#   backend "s3" {
#     # Example: "us-east-1"
#     region         = "<your AWS region>"

#     # Example: "yourcompany-terraform-state"
#     bucket         = "<s3-bucket-name>"
#     use_lockfile = true
#     # The path in S3 to store the state of this terraform directory.
#     # Change this for each environment you deploy to.
#     key = "braintrust.tfstate"
#   }
# }

# Store terraform state locally. Only use this for local testing.
# Use S3 or other remote backends for production deployments.
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
