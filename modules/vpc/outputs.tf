output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.vpc.cidr_block
}

output "public_subnet_1_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_subnet_1.id
}

output "private_subnet_1_id" {
  description = "ID of private subnet 1"
  value       = aws_subnet.private_subnet_1.id
}

output "private_subnet_2_id" {
  description = "ID of private subnet 2"
  value       = aws_subnet.private_subnet_2.id
}

output "private_subnet_3_id" {
  description = "ID of private subnet 3"
  value       = aws_subnet.private_subnet_3.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private_route_table.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public_route_table.id
}

output "default_security_group_id" {
  description = "The ID of the default security group that is automatically created for the VPC"
  value       = aws_vpc.vpc.default_security_group_id
}

output "flow_log_id" {
  description = "ID of the VPC Flow Log, if enabled"
  value       = local.flow_log_enabled ? aws_flow_log.vpc[0].id : null
}

output "flow_log_s3_bucket_arn" {
  description = "ARN of the module-managed S3 bucket used for VPC Flow Logs, if created"
  value       = local.create_flow_log_bucket ? aws_s3_bucket.flow_log[0].arn : null
}

output "flow_log_cloudwatch_log_group_arn" {
  description = "ARN of the module-managed CloudWatch log group used for VPC Flow Logs, if created"
  value       = local.create_flow_log_log_group ? aws_cloudwatch_log_group.flow_log[0].arn : null
}
