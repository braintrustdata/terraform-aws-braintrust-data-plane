output "api_url" {
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL."
  value       = "https://${aws_cloudfront_distribution.dataplane.domain_name}"
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the cloudfront distribution"
  value       = aws_cloudfront_distribution.dataplane.domain_name
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the cloudfront distribution"
  value       = aws_cloudfront_distribution.dataplane.arn
}

output "cloudfront_distribution_id" {
  description = "The ID of the cloudfront distribution"
  value       = aws_cloudfront_distribution.dataplane.id
}

output "cloudfront_hosted_zone_id" {
  description = "The hosted zone ID of the cloudfront distribution"
  value       = aws_cloudfront_distribution.dataplane.hosted_zone_id
}

output "api_gateway_rest_api_arn" {
  description = "The ARN of the API gateway rest api"
  value       = aws_api_gateway_rest_api.api.arn
}
