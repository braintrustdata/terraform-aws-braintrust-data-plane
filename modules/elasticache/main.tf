locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
  elasticache_security_group_ids = length(var.custom_security_group_ids) > 0 ? var.custom_security_group_ids : [aws_security_group.elasticache[0].id]
  redis_url                      = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:${aws_elasticache_cluster.main.cache_nodes[0].port}"
}

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.deployment_name}-elasticache-subnet-group"
  description = "Subnet group for Braintrust elasticache"
  subnet_ids  = var.subnet_ids
  tags        = local.common_tags
}

resource "aws_elasticache_cluster" "main" {
  cluster_id         = "${var.deployment_name}-redis"
  engine             = "redis"
  node_type          = var.redis_instance_type
  num_cache_nodes    = 1
  engine_version     = var.redis_version
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = local.elasticache_security_group_ids
  tags               = local.common_tags
}

resource "aws_secretsmanager_secret" "redis_url" {
  name_prefix = "${var.deployment_name}/RedisUrl-"
  description = "Redis URL for the Braintrust Redis cluster"
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
  description                  = "Allow TCP/6379 (Redis) inbound to Elasticache from ${each.key}."

  security_group_id = aws_security_group.elasticache[0].id
  tags              = local.common_tags
}
