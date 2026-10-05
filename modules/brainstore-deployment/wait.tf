resource "aws_lambda_invocation" "rollout" {
  function_name = aws_lambda_function.waiter.function_name
  qualifier     = "$LATEST"
  input = jsonencode({
    deployment        = local.deployment
    wait_seconds      = 600
    return_on_timeout = true
  })
  lifecycle {
    postcondition {
      condition     = contains(["complete", "timed_out"], try(jsondecode(self.result).status, ""))
      error_message = "Brainstore deployment returned an unexpected result; API deployment is blocked."
    }
  }
}

resource "aws_lambda_invocation" "retry" {
  function_name = aws_lambda_invocation.rollout.function_name
  qualifier     = aws_lambda_invocation.rollout.qualifier
  input = jsonencode({
    deployment   = local.deployment
    wait_seconds = 600
  })
  lifecycle {
    replace_triggered_by = [aws_lambda_invocation.rollout]
    postcondition {
      condition     = try(jsondecode(self.result).status == "complete", false)
      error_message = "Brainstore deployment did not complete; API deployment is blocked."
    }
  }
}

output "completion_id" {
  description = "Completion dependency for this exact Brainstore deployment."
  value       = aws_lambda_invocation.retry.id
}
