resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.deployment_name}-elasticache-subnet-group"
  description = "Subnet group for Braintrust elasticache"
  subnet_ids  = var.subnet_ids
}

resource "aws_elasticache_cluster" "main" {
  cluster_id         = "${var.deployment_name}-redis"
  engine             = "redis"
  node_type          = var.redis_instance_type
  num_cache_nodes    = 1
  engine_version     = var.redis_version
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = var.security_group_ids
} 