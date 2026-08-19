locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
  elasticache_security_group_ids = length(var.custom_security_group_ids) > 0 ? var.custom_security_group_ids : [aws_security_group.elasticache[0].id]

  create_redis_replication_group = var.use_redis_replication_group || var.engine == "valkey"
  create_legacy_redis_cluster    = !var.use_redis_replication_group && var.engine != "valkey"

  engine_version = var.engine == "valkey" ? var.valkey_engine_version : var.redis_version

  legacy_redis_endpoint = try(
    "redis://${aws_elasticache_cluster.main[0].cache_nodes[0].address}:${aws_elasticache_cluster.main[0].cache_nodes[0].port}",
    null
  )
  replication_group_endpoint = try(
    "rediss://${aws_elasticache_replication_group.main[0].primary_endpoint_address}:6379",
    null
  )

  redis_url = local.create_legacy_redis_cluster ? local.legacy_redis_endpoint : local.replication_group_endpoint
}
resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.deployment_name}-elasticache-subnet-group"
  description = "Subnet group for Braintrust ElastiCache Redis/Valkey"
  subnet_ids  = var.subnet_ids
  tags        = local.common_tags
}

resource "terraform_data" "validate_engine_topology" {
  count = var.engine == "valkey" && !var.use_redis_replication_group ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.engine != "valkey" || var.use_redis_replication_group
      error_message = "Valkey requires use_redis_replication_group = true because the legacy aws_elasticache_cluster resource supports Redis only. Set use_redis_replication_group = true before selecting elasticache_engine = \"valkey\"."
    }
  }
}

resource "aws_elasticache_cluster" "main" {
  count = local.create_legacy_redis_cluster && var.engine != "valkey" ? 1 : 0

  cluster_id         = "${var.deployment_name}-redis"
  engine             = var.engine
  node_type          = var.redis_instance_type
  num_cache_nodes    = 1
  engine_version     = local.engine_version
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = local.elasticache_security_group_ids
  tags               = local.common_tags
}

resource "aws_elasticache_replication_group" "main" {
  count = local.create_redis_replication_group ? 1 : 0

  replication_group_id = "${var.deployment_name}-redis-rg"
  description          = "${var.deployment_name} ${var.engine}"

  engine         = var.engine
  engine_version = local.engine_version
  node_type      = var.redis_instance_type

  num_cache_clusters = var.num_cache_clusters
  port               = 6379

  # A replica-backed group should use Multi-AZ placement and automatic
  # failover so a primary or Availability Zone failure can promote a replica.
  multi_az_enabled           = var.num_cache_clusters >= 2
  automatic_failover_enabled = var.num_cache_clusters >= 2

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = local.elasticache_security_group_ids

  transit_encryption_enabled = true
  transit_encryption_mode    = "required"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "redis_url" {
  # Keep this compatibility name for both Redis and Valkey deployments.
  name_prefix = "${var.deployment_name}/RedisUrl-"
  description = "Redis-compatible Redis/Valkey URL for the Braintrust ElastiCache cluster"
  kms_key_id  = var.kms_key_arn
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_url" {
  secret_id     = aws_secretsmanager_secret.redis_url.id
  secret_string = local.redis_url
}

#------------------------------------------------------------------------------
# Security groups
#------------------------------------------------------------------------------
resource "aws_security_group" "elasticache" {
  count  = length(var.custom_security_group_ids) == 0 ? 1 : 0
  name   = "${var.deployment_name}-elasticache"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.deployment_name}-elasticache" }, local.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_allow_ingress_from_authorized_security_groups" {
  for_each = length(var.custom_security_group_ids) == 0 ? var.authorized_security_groups : {}

  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow TCP/6379 (Redis/Valkey) inbound to Elasticache from ${each.key}."

  security_group_id = aws_security_group.elasticache[0].id
  tags              = local.common_tags
}
