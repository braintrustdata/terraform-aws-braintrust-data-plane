## Cluster

output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "Name of the EKS cluster."
}

output "cluster_arn" {
  value       = aws_eks_cluster.this.arn
  description = "ARN of the EKS cluster (used by services_common for Pod Identity trust policy scoping)."
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "API server endpoint of the EKS cluster."
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
  description = "Base64-encoded CA certificate data for the cluster."
}

output "cluster_security_group_id" {
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description = "Primary security group the EKS control plane attaches to Auto Mode nodes. Used to authorize RDS/Redis access."
}

output "node_iam_role_arn" {
  value       = aws_iam_role.node.arn
  description = "ARN of the IAM role assumed by Auto Mode nodes (needed by any custom NodeClass the eks-deploy submodule creates)."
}

output "node_iam_role_name" {
  value       = aws_iam_role.node.name
  description = "Name of the Auto Mode node IAM role."
}

## NLB

output "nlb_arn" {
  value       = aws_lb.api.arn
  description = "ARN of the pre-created internal NLB."
}

output "nlb_name" {
  value       = aws_lb.api.name
  description = "Name of the pre-created NLB (used by the chart's aws-load-balancer-name annotation to adopt it)."
}

output "nlb_security_group_id" {
  value       = aws_security_group.nlb_cloudfront.id
  description = "Security group ID attached to the NLB (passed into the chart via aws-load-balancer-security-groups)."
}

## CloudFront

output "cloudfront_distribution_domain_name" {
  value       = aws_cloudfront_distribution.dataplane.domain_name
  description = "CloudFront distribution domain name."
}

output "cloudfront_distribution_arn" {
  value       = aws_cloudfront_distribution.dataplane.arn
  description = "CloudFront distribution ARN."
}

output "cloudfront_distribution_hosted_zone_id" {
  value       = aws_cloudfront_distribution.dataplane.hosted_zone_id
  description = "CloudFront distribution hosted zone ID (for Route 53 alias records)."
}
