output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.vpc.cidr_block
}

output "public_subnet_1_id" {
  description = "ID of the first public subnet"
  value       = aws_subnet.public_subnet_1.id
}

output "public_subnet_2_id" {
  description = "ID of the second public subnet. Null when public_subnet_2_cidr is not set."
  value       = var.public_subnet_2_cidr != null ? aws_subnet.public_subnet_2[0].id : null
}

output "public_subnet_3_id" {
  description = "ID of the third public subnet. Null when public_subnet_3_cidr is not set."
  value       = var.public_subnet_3_cidr != null ? aws_subnet.public_subnet_3[0].id : null
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
