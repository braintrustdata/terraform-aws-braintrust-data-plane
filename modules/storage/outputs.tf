output "brainstore_bucket_arn" {
  description = "The ARN of the S3 bucket used by Brainstore"
  value       = aws_s3_bucket.brainstore.arn
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
  value       = aws_s3_bucket.brainstore.id
}

output "code_bundle_bucket_id" {
  description = "The ID of the code bundle bucket"
  value       = aws_s3_bucket.code_bundle_bucket.id
}

output "lambda_responses_bucket_id" {
  description = "The ID of the lambda responses bucket"
  value       = aws_s3_bucket.lambda_responses_bucket.id
}
