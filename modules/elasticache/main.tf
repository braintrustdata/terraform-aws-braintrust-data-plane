locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  # Migration logic:
  # "default" = both old and new exist (migration state)
  # "serverless" = only new exists (final state)
  use_old_cluster = var.cache_mode == "default"
  use_serverless  = true  # Always create serverless during migration
}

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.deployment_name}-elasticache-subnet-group"
  description = "Subnet group for Braintrust elasticache"
  subnet_ids  = var.subnet_ids
  tags        = local.common_tags
}

resource "aws_elasticache_cluster" "main" {
  count = local.use_old_cluster ? 1 : 0

  cluster_id         = "${var.deployment_name}-redis"
  engine             = "redis"
  node_type          = var.redis_instance_type
  num_cache_nodes    = 1
  engine_version     = var.redis_version
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.elasticache.id]
  tags               = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elasticache_serverless_cache" "valkey" {
  count = local.use_serverless ? 1 : 0

  engine = "valkey"
  name   = "${var.deployment_name}-valkey"

  cache_usage_limits {
    data_storage {
      maximum = 10
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 5000
    }
  }

  security_group_ids = [aws_security_group.elasticache.id]
  subnet_ids         = var.subnet_ids
  tags               = local.common_tags
}

#------------------------------------------------------------------------------
# Security groups
#------------------------------------------------------------------------------
resource "aws_security_group" "elasticache" {
  name   = "${var.deployment_name}-elasticache"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.deployment_name}-elasticache" }, local.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_allow_ingress_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow TCP/6379 (Redis) inbound to Elasticache from ${each.key}."

  security_group_id = aws_security_group.elasticache.id
  tags              = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "elasticache_allow_egress_all" {

  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic from Elasticache instances."
  security_group_id = aws_security_group.elasticache.id
  tags              = local.common_tags
}
