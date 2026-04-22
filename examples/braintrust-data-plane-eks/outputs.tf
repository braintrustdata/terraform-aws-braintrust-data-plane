output "api_url" {
  value       = module.braintrust.api_url
  description = "Braintrust API URL — enter this in the Braintrust dashboard under Settings > Data Plane > API URL"
}

output "eks_cluster_name" {
  value       = module.braintrust.eks_cluster_name
  description = "EKS cluster name"
}

output "eks_cluster_endpoint" {
  value       = module.braintrust.eks_cluster_endpoint
  description = "EKS cluster API server endpoint"
}

output "cloudfront_distribution_domain_name" {
  value       = module.braintrust.cloudfront_distribution_domain_name
  description = "CloudFront distribution domain name"
}

output "postgres_database_identifier" {
  value       = module.braintrust.postgres_database_identifier
  description = "RDS instance identifier"
}
