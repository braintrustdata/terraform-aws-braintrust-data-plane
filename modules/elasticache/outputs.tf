output "redis_endpoint" {
  value = local.use_serverless ? (
    aws_elasticache_serverless_cache.valkey[0].endpoint[0].address
  ) : (
    local.use_old_cluster ? aws_elasticache_cluster.main[0].cache_nodes[0].address : null
  )
  description = "Redis endpoint address"
}

output "redis_port" {
  value = local.use_serverless ? (
    aws_elasticache_serverless_cache.valkey[0].endpoint[0].port
  ) : (
    local.use_old_cluster ? aws_elasticache_cluster.main[0].cache_nodes[0].port : null
  )
  description = "Redis port"
}

output "redis_arn" {
  value = local.use_serverless ? (
    aws_elasticache_serverless_cache.valkey[0].arn
  ) : (
    local.use_old_cluster ? aws_elasticache_cluster.main[0].arn : null
  )
  description = "Redis ARN"
}

output "redis_security_group_id" {
  value       = aws_security_group.elasticache.id
  description = "The ID of the security group for the Elasticache instance"
}