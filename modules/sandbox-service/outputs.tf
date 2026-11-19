output "endpoint" {
  description = "Private mTLS Sandbox Service discovery URL."
  value       = "https://${local.hostname}:9400"
  depends_on  = [helm_release.sandbox]
}

output "client_tls_secret_arn" {
  description = "Client TLS bundle ARN, available after the release has been installed."
  value       = var.client_tls_secret_arn
  depends_on  = [helm_release.sandbox]
}

output "client_tls_secret_version" {
  description = "Installed client bundle version, used to redeploy consumers on rotation."
  value       = local.tls_versions.client
  depends_on  = [helm_release.sandbox]
}

output "worker_security_group_id" {
  description = "Sandbox worker security group; destinations own inbound authorizations."
  value       = aws_security_group.workers.id
}

output "system_security_group_id" {
  description = "System node security group for caller-managed private endpoint authorizations."
  value       = aws_security_group.system.id
}

output "cluster_name" {
  description = "Private Sandbox Service EKS cluster name."
  value       = aws_eks_cluster.sandbox.name
}

output "worker_node_group_name" {
  description = "Current Terraform-managed worker pool."
  value       = aws_eks_node_group.workers.node_group_name
}

output "sandbox_image" {
  description = "Sandbox Service guest image pinned with the chart and service release."
  value       = local.versions["sandbox-image"]
}

output "private_subnet_ids" {
  description = "Dedicated Sandbox Service subnet IDs."
  value       = var.private_subnet_ids
}

output "kubernetes_api_url" {
  description = "Private Kubernetes discovery configuration for Loop Runtime."
  value       = aws_eks_cluster.sandbox.endpoint
}

output "kubernetes_ca" {
  description = "Private Kubernetes discovery configuration for Loop Runtime."
  value       = aws_eks_cluster.sandbox.certificate_authority[0].data
}
