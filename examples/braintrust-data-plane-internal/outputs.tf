output "api_url" {
  value       = module.braintrust-data-plane.api_url
  description = "The primary endpoint for the dataplane API. Configure this value in the Braintrust dashboard under API URL."
}

output "api_ecs_alb_dns_name" {
  value       = module.braintrust-data-plane.api_ecs_alb_dns_name
  description = "Internal load balancer DNS name. Point your private DNS record at this value."
}

output "api_ecs_alb_zone_id" {
  value       = module.braintrust-data-plane.api_ecs_alb_zone_id
  description = "Hosted zone ID for the internal load balancer alias target."
}

output "api_ecs_dns_record_fqdn" {
  value       = module.braintrust-data-plane.api_ecs_dns_record_fqdn
  description = "FQDN of the module-created DNS alias record."
}

output "api_ecs_acm_certificate_arn" {
  value       = module.braintrust-data-plane.api_ecs_acm_certificate_arn
  description = "ARN of the ACM certificate used by the internal endpoint."
}

output "main_vpc_id" {
  value       = module.braintrust-data-plane.main_vpc_id
  description = "ID of the VPC that contains the Braintrust data plane."
}
