output "api_url" {
  value       = module.braintrust-data-plane.api_url
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL."
}

output "observability_instance_id" {
  value       = aws_instance.observability.id
  description = "EC2 instance ID for the sandbox Grafana/Loki/Prometheus/Tempo/OpenTelemetry host."
}

output "observability_private_dns" {
  value       = aws_instance.observability.private_dns
  description = "Private DNS name for the sandbox observability host. Use this for Brainstore OTLP endpoint configuration."
}

output "observability_grafana_url" {
  value       = "http://${aws_instance.observability.private_dns}:3001"
  description = "Private Grafana URL. Use SSM port forwarding or VPC access to reach it."
}

output "observability_otlp_http_endpoint" {
  value       = "http://${aws_instance.observability.private_dns}:4318"
  description = "Private OTLP HTTP endpoint for Brainstore telemetry."
}

output "observability_ssm_grafana_tunnel_command" {
  value       = "aws ssm start-session --target ${aws_instance.observability.id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"3001\"],\"localPortNumber\":[\"3001\"]}' --region ${data.aws_region.current.region} --profile sandbox"
  description = "Command to tunnel Grafana to http://localhost:3001 without exposing it publicly."
}
