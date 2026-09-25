# Each invocation has a bounded budget below Lambda's execution limit. The
# continuation is Terraform state; the function always checks live AWS state.
resource "aws_lambda_invocation" "first" {
  function_name = aws_lambda_function.waiter.function_name
  qualifier     = aws_lambda_function.waiter.version
  input = jsonencode({
    deployment   = local.deployment
    continuation = null
    wait_seconds = 600
    final        = false
  })
}

resource "aws_lambda_invocation" "second" {
  function_name = aws_lambda_function.waiter.function_name
  qualifier     = aws_lambda_function.waiter.version
  input = jsonencode({
    deployment   = local.deployment
    continuation = jsondecode(aws_lambda_invocation.first.result).continuation
    wait_seconds = 600
    final        = false
  })
}

resource "aws_lambda_invocation" "final" {
  function_name = aws_lambda_function.waiter.function_name
  qualifier     = aws_lambda_function.waiter.version
  input = jsonencode({
    deployment   = local.deployment
    continuation = jsondecode(aws_lambda_invocation.second.result).continuation
    wait_seconds = 600
    final        = true
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
  value       = aws_lambda_invocation.final.id
}
