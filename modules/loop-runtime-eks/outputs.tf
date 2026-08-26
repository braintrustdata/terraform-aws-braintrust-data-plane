output "role_arn" {
  description = "ARN of the IAM role for the Loop Runtime EKS service account."
  value       = aws_iam_role.loop_runtime.arn
}

output "role_name" {
  description = "Name of the IAM role for the Loop Runtime EKS service account."
  value       = aws_iam_role.loop_runtime.name
}
