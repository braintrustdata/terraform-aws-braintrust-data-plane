output "namespace" {
  value       = kubernetes_namespace.braintrust.metadata[0].name
  description = "Namespace the Braintrust workloads were deployed into."
}

output "braintrust_release_name" {
  value       = helm_release.braintrust.name
  description = "Name of the Braintrust Helm release."
}
