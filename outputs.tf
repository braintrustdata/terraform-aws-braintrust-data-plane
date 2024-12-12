output "main_vpc_id" {
  value       = module.main_vpc.vpc_id
  description = "ID of the main VPC that contains the Braintrust resources"
}

output "quarantine_vpc_id" {
  value       = module.quarantine_vpc.vpc_id
  description = "ID of the optional quarantine VPC that user functions run inside of."
}

output "main_vpc_public_subnet_1_id" {
  value       = module.main_vpc.public_subnet_1_id
  description = "ID of the public subnet in the main VPC"
}

output "main_vpc_private_subnet_1_id" {
  value       = module.main_vpc.private_subnet_1_id
  description = "ID of the first private subnet in the main VPC"
}

output "main_vpc_private_subnet_2_id" {
  value       = module.main_vpc.private_subnet_2_id
  description = "ID of the second private subnet in the main VPC"
}

output "main_vpc_private_subnet_3_id" {
  value       = module.main_vpc.private_subnet_3_id
  description = "ID of the third private subnet in the main VPC"
}
