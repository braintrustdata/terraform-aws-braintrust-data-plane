output "endpoint" {
  description = "Private mTLS Sandbox Service discovery URL."
  value       = "https://${local.hostname}:9400"
}

output "client_tls_secret_arn" {
  description = "Client TLS bundle ARN, available after the release has been installed."
  value       = aws_cloudformation_stack.release.outputs["ClientTlsSecretArn"]
}

output "worker_security_group_id" {
  description = "Sandbox worker security group; destinations own inbound authorizations."
  value       = aws_security_group.workers.id
}

output "cluster_name" {
  description = "Private Sandbox Service EKS cluster name."
  value       = aws_eks_cluster.sandbox.name
}

output "worker_node_group_name" {
  description = "Current worker pool managed by the release stack."
  value       = aws_cloudformation_stack.release.outputs["NodeGroupName"]
}

output "sandbox_image" {
  description = "Sandbox Service guest image pinned with the chart and service release."
  value       = local.versions["sandbox-image"]
}
