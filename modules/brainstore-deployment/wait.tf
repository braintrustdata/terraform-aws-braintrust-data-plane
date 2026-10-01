resource "aws_lambda_invocation" "rollout" {
  function_name = aws_lambda_function.waiter.function_name
  # Use the current code without rerunning solely for a helper version change.
  qualifier = "$LATEST"
  input = jsonencode({
    deployment   = local.deployment
    wait_seconds = 600
  })
  lifecycle {
    postcondition {
      condition     = try(jsondecode(self.result).status == "complete", false)
      error_message = "Brainstore deployment did not complete; API deployment is blocked."
    }
  }
}

output "completion_id" {
  description = "Completion dependency for this exact Brainstore deployment."
  value       = aws_lambda_invocation.rollout.id
}
