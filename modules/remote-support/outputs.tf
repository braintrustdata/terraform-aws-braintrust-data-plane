output "braintrust_support_role_arn" {
  description = "ARN of the Role that grants Braintrust team remote support. Share this with the Braintrust team."
  value       = local.has_braintrust_support_access ? aws_iam_role.braintrust_support[0].arn : null
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host that Braintrust support staff can connect to using EC2 Instance Connect. Share this with the Braintrust team."
  value       = var.enable_braintrust_support_shell_access ? aws_instance.bastion[0].id : null
}
