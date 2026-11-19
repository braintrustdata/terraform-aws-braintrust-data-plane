
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
