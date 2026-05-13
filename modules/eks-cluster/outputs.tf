output "cluster_id" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "The name of the EKS cluster (alias for cluster_id)"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC issuer (for IRSA)"
  value       = try(aws_eks_cluster.main.identity[0].oidc[0].issuer, "")
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = aws_eks_cluster.main.status
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN of the EKS node groups"
  value       = aws_iam_role.node_group.arn
}

output "node_group_iam_role_name" {
  description = "IAM role name of the EKS node groups"
  value       = aws_iam_role.node_group.name
}

output "system_node_group_id" {
  description = "ID of the system node group. Empty string when use_eks_auto_mode is true."
  value       = var.use_eks_auto_mode ? "" : aws_eks_node_group.system[0].id
}

output "system_node_group_status" {
  description = "Status of the system node group. Empty string when use_eks_auto_mode is true."
  value       = var.use_eks_auto_mode ? "" : aws_eks_node_group.system[0].status
}

output "services_node_group_id" {
  description = "ID of the services node group. Empty string when use_eks_auto_mode is true."
  value       = var.use_eks_auto_mode ? "" : aws_eks_node_group.services[0].id
}

output "services_node_group_status" {
  description = "Status of the services node group. Empty string when use_eks_auto_mode is true."
  value       = var.use_eks_auto_mode ? "" : aws_eks_node_group.services[0].status
}

output "brainstore_reader_node_group_id" {
  description = "ID of the brainstore reader node group. Empty string when use_eks_auto_mode is true."
  value       = var.use_eks_auto_mode ? "" : aws_eks_node_group.brainstore_reader[0].id
}

output "brainstore_reader_node_group_status" {
  description = "Status of the brainstore reader node group. Empty string when use_eks_auto_mode is true."
  value       = var.use_eks_auto_mode ? "" : aws_eks_node_group.brainstore_reader[0].status
}

output "brainstore_writer_node_group_id" {
  description = "ID of the brainstore writer node group. Empty string when use_eks_auto_mode is true."
  value       = var.use_eks_auto_mode ? "" : aws_eks_node_group.brainstore_writer[0].id
}

output "brainstore_writer_node_group_status" {
  description = "Status of the brainstore writer node group. Empty string when use_eks_auto_mode is true."
  value       = var.use_eks_auto_mode ? "" : aws_eks_node_group.brainstore_writer[0].status
}

output "services_spot_node_group_id" {
  description = "ID of the services spot node group. Empty string if enable_services_spot_node_group is false."
  value       = !var.use_eks_auto_mode && var.enable_services_spot_node_group ? aws_eks_node_group.services_spot[0].id : ""
}

output "services_spot_node_group_status" {
  description = "Status of the services spot node group. Empty string if enable_services_spot_node_group is false."
  value       = !var.use_eks_auto_mode && var.enable_services_spot_node_group ? aws_eks_node_group.services_spot[0].status : ""
}

output "brainstore_spot_node_group_id" {
  description = "ID of the brainstore spot node group. Empty string if disabled or when use_eks_auto_mode is true."
  value       = !var.use_eks_auto_mode && var.enable_brainstore_spot_node_group ? aws_eks_node_group.brainstore_spot[0].id : ""
}

output "brainstore_spot_node_group_status" {
  description = "Status of the brainstore spot node group. Empty string if disabled or when use_eks_auto_mode is true."
  value       = !var.use_eks_auto_mode && var.enable_brainstore_spot_node_group ? aws_eks_node_group.brainstore_spot[0].status : ""
}

output "lb_controller_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller Pod Identity association."
  value       = aws_iam_role.lb_controller.arn
}

output "braintrust_api_pod_identity_association_id" {
  description = "ID of the Pod Identity association for the Braintrust API service account."
  value       = aws_eks_pod_identity_association.braintrust_api.association_id
}

output "brainstore_pod_identity_association_id" {
  description = "ID of the Pod Identity association for the Brainstore service account."
  value       = aws_eks_pod_identity_association.brainstore.association_id
}

output "nlb_arn" {
  description = "ARN of the pre-created internal NLB used by CloudFront VPC Origin."
  value       = var.enable_cloudfront_nlb_ingress ? aws_lb.api[0].arn : null
}

output "nlb_name" {
  description = "Name of the pre-created internal NLB. Pass to the aws-load-balancer-name service annotation so the controller adopts it."
  value       = var.enable_cloudfront_nlb_ingress ? aws_lb.api[0].name : null
}

output "nlb_dns_name" {
  description = "DNS name of the pre-created internal NLB."
  value       = var.enable_cloudfront_nlb_ingress ? aws_lb.api[0].dns_name : null
}

output "nlb_security_group_id" {
  description = "Security group ID attached to the internal NLB."
  value       = var.enable_cloudfront_nlb_ingress ? aws_security_group.nlb_cloudfront[0].id : null
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = var.enable_cloudfront_nlb_ingress ? aws_cloudfront_distribution.dataplane[0].domain_name : null
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = var.enable_cloudfront_nlb_ingress ? aws_cloudfront_distribution.dataplane[0].arn : null
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID."
  value       = var.enable_cloudfront_nlb_ingress ? aws_cloudfront_distribution.dataplane[0].hosted_zone_id : null
}

output "api_url" {
  description = "Primary Braintrust API URL for this EKS deployment."
  value       = var.enable_cloudfront_nlb_ingress ? "https://${var.custom_domain != null ? var.custom_domain : aws_cloudfront_distribution.dataplane[0].domain_name}" : null
}
