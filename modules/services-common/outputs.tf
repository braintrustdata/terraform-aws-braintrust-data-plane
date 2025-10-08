output "brainstore_instance_security_group_id" {
  description = "The ID of the security group for the Brainstore instances"
  value       = aws_security_group.brainstore_instance.id
}

output "brainstore_iam_role_arn" {
  description = "The ARN of the IAM role for Brainstore EC2 instances"
  value       = aws_iam_role.brainstore_ec2_role.arn
}

output "brainstore_iam_role_name" {
  description = "The name of the IAM role for Brainstore EC2 instances"
  value       = aws_iam_role.brainstore_ec2_role.name
}

