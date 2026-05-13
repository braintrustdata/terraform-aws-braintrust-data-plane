output "namespace" {
  value       = kubernetes_namespace.braintrust.metadata[0].name
  description = "Namespace the Braintrust workloads were deployed into."
}

output "braintrust_release_name" {
  value       = "braintrust"
  description = "Name to use for the Braintrust Helm release."
}

output "braintrust_helm_release_managed" {
  value       = var.manage_braintrust_helm_release
  description = "True when Terraform manages the Braintrust Helm release."
}

output "braintrust_helm_values_yaml" {
  value       = local.helm_values_yaml
  description = "Generated multi-document Helm values for the Braintrust chart. Write to a file and pass with --values when doing a manual helm install/upgrade."
}

output "aws_load_balancer_controller_release_name" {
  value       = helm_release.aws_load_balancer_controller.name
  description = "Name of the AWS Load Balancer Controller Helm release."
}
