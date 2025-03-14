output "s3_bucket" {
  description = "The ID of the S3 bucket used by Brainstore"
  value       = aws_s3_bucket.brainstore.id
}

output "dns_name" {
  description = "The DNS name of the Brainstore NLB"
  value       = aws_lb.brainstore.dns_name
}

output "port" {
  description = "The port used by Brainstore"
  value       = var.port
}
