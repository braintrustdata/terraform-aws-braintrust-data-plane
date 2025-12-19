output "valkey_endpoint" {
  value       = aws_elasticache_serverless_cache.valkey.endpoint[0].address
  description = "Valkey endpoint address"
}

output "valkey_port" {
  value       = aws_elasticache_serverless_cache.valkey.endpoint[0].port
  description = "Valkey port"
}

output "valkey_arn" {
  value       = aws_elasticache_serverless_cache.valkey.arn
  description = "Valkey ARN"
}

output "valkey_security_group_id" {
  value       = aws_security_group.elasticache.id
  description = "The ID of the security group for the Elasticache instance"
}