output "redis_endpoint" {
  value       = aws_elasticache_serverless_cache.valkey.endpoint[0].address
  description = "Redis endpoint address"
}

output "redis_port" {
  value       = aws_elasticache_serverless_cache.valkey.endpoint[0].port
  description = "Redis port"
}

output "redis_arn" {
  value       = aws_elasticache_serverless_cache.valkey.arn
  description = "Redis ARN"
}

output "redis_security_group_id" {
  value       = aws_security_group.elasticache.id
  description = "The ID of the security group for the Elasticache instance"
}