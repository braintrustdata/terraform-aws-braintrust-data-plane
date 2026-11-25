output "brainstore_bucket_arn" {
  description = "The ARN of the S3 bucket used by Brainstore"
  value       = local.brainstore_bucket_arn
}

output "code_bundle_bucket_arn" {
  description = "The ARN of the code bundle bucket"
  value       = aws_s3_bucket.code_bundle_bucket.arn
}

output "lambda_responses_bucket_arn" {
  description = "The ARN of the lambda responses bucket"
  value       = aws_s3_bucket.lambda_responses_bucket.arn
}

output "brainstore_bucket_id" {
  description = "The ID of the S3 bucket used by Brainstore"
  value       = local.brainstore_bucket_id
}

output "code_bundle_bucket_id" {
  description = "The ID of the code bundle bucket"
  value       = aws_s3_bucket.code_bundle_bucket.id
}

output "lambda_responses_bucket_id" {
  description = "The ID of the lambda responses bucket"
  value       = aws_s3_bucket.lambda_responses_bucket.id
}

output "sandbox_filesystems_bucket_arn" {
  description = "ARN of the deployment-owned sandbox checkpoint bucket."
  value       = aws_s3_bucket.sandbox_filesystems.arn
  depends_on = [
    aws_s3_bucket_public_access_block.sandbox_filesystems,
    aws_s3_bucket_server_side_encryption_configuration.sandbox_filesystems,
    aws_s3_bucket_ownership_controls.sandbox_filesystems,
    aws_s3_bucket_lifecycle_configuration.sandbox_filesystems,
    aws_s3_bucket_policy.sandbox_filesystems,
  ]
}
output "sandbox_filesystems_bucket_id" {
  description = "Name of the deployment-owned sandbox checkpoint bucket."
  value       = aws_s3_bucket.sandbox_filesystems.id
  depends_on = [
    aws_s3_bucket_public_access_block.sandbox_filesystems,
    aws_s3_bucket_server_side_encryption_configuration.sandbox_filesystems,
    aws_s3_bucket_ownership_controls.sandbox_filesystems,
    aws_s3_bucket_lifecycle_configuration.sandbox_filesystems,
    aws_s3_bucket_policy.sandbox_filesystems,
  ]
}
