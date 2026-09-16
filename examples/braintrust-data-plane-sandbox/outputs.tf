output "api_url" {
  value       = module.braintrust-data-plane.api_url
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL."
}

output "observability_instance_id" {
  value       = try(aws_instance.observability[0].id, null)
  description = "EC2 instance ID for the sandbox Grafana/Loki/Prometheus/Tempo/OpenTelemetry host."
}

output "observability_private_dns" {
  value       = var.enable_observability ? local.observability_dns_name : null
  description = "Stable private DNS name for the sandbox observability host. Use this for Brainstore OTLP endpoint configuration."
}

output "observability_grafana_url" {
  value       = var.enable_observability ? "http://${local.observability_dns_name}:3001" : null
  description = "Private Grafana URL. Use SSM port forwarding or VPC access to reach it."
}

output "observability_otlp_http_endpoint" {
  value       = var.enable_observability ? local.observability_otlp_endpoint : null
  description = "Private OTLP HTTP endpoint for Brainstore telemetry."
}

output "observability_ssm_grafana_tunnel_command" {
  value       = var.enable_observability ? "aws ssm start-session --target ${aws_instance.observability[0].id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"3001\"],\"localPortNumber\":[\"3001\"]}' --region ${data.aws_region.current.region} --profile sandbox" : null
  description = "Command to tunnel Grafana to http://localhost:3001 without exposing it publicly."
}
