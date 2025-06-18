output "s3_bucket" {
  description = "The ID of the S3 bucket used by Brainstore"
  value       = aws_s3_bucket.brainstore.id
}

output "dns_name" {
  description = "The DNS name of the Brainstore NLB"
  value       = aws_lb.brainstore.dns_name
}

output "writer_dns_name" {
  description = "The DNS name of the Brainstore writer NLB, if enabled"
  value       = local.has_writer_nodes ? aws_lb.brainstore_writer[0].dns_name : null
}

output "port" {
  description = "The port used by Brainstore"
  value       = var.port
}
