# provider "aws" {
#   region = "<your AWS region>"

#   # Optional, but recommended. Use a specific AWS credential profile for creating the Braintrust
#   # resources. This helps prevent accidental changes in the wrong account.
#   profile = "<your AWS credential profile>"

#   # Optional, but recommended. Only allow running in a specific AWS account.
#   # This is helpful for preventing accidental changes in the wrong account.
#   allowed_account_ids = ["<your AWS account ID>"]

#   # Optionally, you can add default tags to all resources created by this module.
#   default_tags {
#     tags = {
#       YourCustomTag = "<your-custom-value>"
#     }
#   }
# }

# When enabling Sandbox Service, uncomment this provider and use the same AWS
# region and IAM identity as the AWS provider. Run Terraform from a network that
# can reach the private EKS API; authorize the runner's security group in main.tf.
# Keep the cluster connection configuration available until Helm is uninstalled.
# provider "helm" {
#   kubernetes = {
#     host = module.braintrust-data-plane.sandbox_service_kubernetes_api_url
#     cluster_ca_certificate = base64decode(module.braintrust-data-plane.sandbox_service_kubernetes_ca)
#     exec = {
#       api_version = "client.authentication.k8s.io/v1beta1"
#       command     = "aws"
#       args = [
#         "eks", "get-token", "--region", "<your AWS region>",
#         "--cluster-name", module.braintrust-data-plane.sandbox_service_cluster_name,
#       ]
#     }
#   }
# }
