output "role_arn" {
  description = "ARN of the IAM role for the Loop Runtime EKS service account."
  value       = aws_iam_role.loop_runtime.arn
}

output "role_name" {
  description = "Name of the IAM role for the Loop Runtime EKS service account."
  value       = aws_iam_role.loop_runtime.name
}

output "helm_brainstore_locks_s3_path" {
  description = "S3 path prefix used by the Helm-managed Brainstore lock namespace."
  value       = local.locks_s3_path
}

output "assume_role_policy_json" {
  description = "Assume-role policy for the Loop Runtime EKS IAM role."
  value       = local.assume_role_policy
}
