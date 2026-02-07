output "dns_name" {
  description = "The DNS name of the Brainstore NLB"
  value       = aws_lb.brainstore.dns_name
}

output "port" {
  description = "The port used by Brainstore"
  value       = var.port
}

output "brainstore_elb_security_group_id" {
  description = "The ID of the security group for the Brainstore ELB"
  value       = aws_security_group.brainstore_elb.id
}
