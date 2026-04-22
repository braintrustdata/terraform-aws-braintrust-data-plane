## Cluster

output "cluster_name" {
  value       = module.eks.cluster_name
  description = "Name of the EKS cluster."
}

output "cluster_arn" {
  value       = module.eks.cluster_arn
  description = "ARN of the EKS cluster."
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "API server endpoint of the EKS cluster."
}

output "cluster_certificate_authority_data" {
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
  description = "Base64-encoded CA certificate data for the EKS cluster."
}

output "cluster_oidc_issuer_url" {
  value       = module.eks.cluster_oidc_issuer_url
  description = "OIDC issuer URL for the EKS cluster (with https:// prefix)."
}

output "oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "ARN of the IAM OIDC provider for the EKS cluster."
}

output "node_security_group_id" {
  value       = module.eks.node_security_group_id
  description = "Security group ID for the EKS worker nodes (used to authorize RDS/Redis access)."
}

## IRSA trust policies (consumed by services_common as override_*_trust_policy)

output "api_iam_trust_policy" {
  value       = local.api_iam_trust_policy
  description = "OIDC-only trust policy for the API handler IAM role, scoped to the API service account."
}

output "brainstore_iam_trust_policy" {
  value       = local.brainstore_iam_trust_policy
  description = "OIDC-only trust policy for the Brainstore IAM role, scoped to the Brainstore service account."
}

## Load Balancer Controller IAM

output "lb_controller_role_arn" {
  value       = aws_iam_role.lb_controller.arn
  description = "ARN of the IAM role for the AWS Load Balancer Controller (consumed by eks-deploy as an IRSA annotation)."
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
