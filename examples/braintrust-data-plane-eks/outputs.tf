output "api_url" {
  value       = module.braintrust.api_url
  description = "Braintrust API URL — enter this in the Braintrust dashboard under Settings > Data Plane > API URL."
}

output "cloudfront_distribution_domain_name" {
  value       = module.braintrust.cloudfront_distribution_domain_name
  description = "CloudFront distribution domain name."
}

output "postgres_database_identifier" {
  value       = module.braintrust.postgres_database_identifier
  description = "RDS instance identifier."
}
