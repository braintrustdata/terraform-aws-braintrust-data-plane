output "redis_endpoint" {
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
  description = "Redis endpoint address"
}

output "redis_port" {
  value       = aws_elasticache_cluster.main.cache_nodes[0].port
  description = "Redis port"
} 