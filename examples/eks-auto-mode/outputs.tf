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

output "eks_braintrust_helm_release_managed" {
  value       = module.braintrust_deploy.braintrust_helm_release_managed
  description = "True in this example because Terraform manages the Braintrust Helm release."
}

output "eks_braintrust_helm_values" {
  value       = module.braintrust_deploy.braintrust_helm_values_yaml
  description = "Generated multi-document Helm values passed to the Terraform-managed Braintrust Helm release."
}

output "braintrust_release_name" {
  value       = module.braintrust_deploy.braintrust_release_name
  description = "Helm release name used for the Terraform-managed Braintrust application deployment."
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
