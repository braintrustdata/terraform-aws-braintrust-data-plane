output "api_url" {
  value       = module.braintrust.api_url
  description = "Braintrust API URL to register in the Braintrust dashboard."
}

output "connect_to_cluster" {
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${module.braintrust.eks_cluster_name}"
  description = "Command to configure kubectl for the EKS cluster."
}

output "eks_cluster_name" {
  value       = module.braintrust.eks_cluster_name
  description = "EKS cluster name."
}

output "eks_namespace" {
  value       = module.braintrust.eks_namespace
  description = "Kubernetes namespace where Braintrust is deployed."
}

output "cloudfront_distribution_domain_name" {
  value       = module.braintrust.cloudfront_distribution_domain_name
  description = "CloudFront distribution domain name."
}

output "cloudfront_distribution_hosted_zone_id" {
  value       = module.braintrust.cloudfront_distribution_hosted_zone_id
  description = "CloudFront hosted zone ID for Route53 alias records."
}

output "eks_nlb_name" {
  value       = module.braintrust.eks_nlb_name
  description = "Internal NLB name adopted by the Braintrust API Kubernetes service."
}

output "postgres_database_identifier" {
  value       = module.braintrust.postgres_database_identifier
  description = "RDS instance identifier."
}
