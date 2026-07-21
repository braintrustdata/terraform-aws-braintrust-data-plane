output "redis_endpoint" {
  value = local.create_legacy_redis_cluster ? aws_elasticache_cluster.main[0].cache_nodes[0].address : aws_elasticache_replication_group.main[0].primary_endpoint_address
}

output "redis_port" {
  value       = local.create_legacy_redis_cluster ? aws_elasticache_cluster.main[0].cache_nodes[0].port : aws_elasticache_replication_group.main[0].port
  description = "Redis port"
}

output "redis_arn" {
  value       = local.create_legacy_redis_cluster ? aws_elasticache_cluster.main[0].arn : aws_elasticache_replication_group.main[0].arn
  description = "Redis ARN"
}

output "redis_security_group_id" {
  value       = local.elasticache_security_group_ids[0]
  description = "The ID of the first security group for the Elasticache instance"
}

output "redis_url_secret_arn" {
  value       = aws_secretsmanager_secret.redis_url.arn
  description = "ARN of the secret containing the Redis URL"
}
