output "rest_api_id" {
  description = "ID of the API Gateway REST API."
  value       = aws_api_gateway_rest_api.api.id
}

output "rest_api_arn" {
  description = "ARN of the API Gateway REST API."
  value       = aws_api_gateway_rest_api.api.arn
}

output "execution_arn" {
  description = "Execution ARN of the API Gateway REST API."
  value       = "arn:aws:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api.id}"
}

output "name" {
  description = "Name of the API Gateway REST API."
  value       = aws_api_gateway_rest_api.api.name
}

output "stage_name" {
  description = "Deployed API Gateway stage name."
  value       = aws_api_gateway_stage.api.stage_name
}
