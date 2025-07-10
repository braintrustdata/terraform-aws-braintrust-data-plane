locals {
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }
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
  security_group_ids = [aws_security_group.elasticache.id]
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

resource "aws_security_group_rule" "elasticache_allow_ingress_from_brainstore" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.brainstore_ec2_security_group_id
  description              = "Allow TCP/6379 (Redis) inbound to Elasticache from Brainstore EC2 instances."

  security_group_id = aws_security_group.elasticache.id
}

resource "aws_security_group_rule" "elasticache_allow_ingress_from_lambda" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.lambda_security_group_id
  description              = "Allow TCP/6379 (Redis) inbound to Elasticache from Lambdas."

  security_group_id = aws_security_group.elasticache.id
}

resource "aws_security_group_rule" "elasticache_allow_ingress_from_remote_support" {
  count = var.remote_support_security_group_id != null ? 1 : 0

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.remote_support_security_group_id
  description              = "Allow TCP/6379 (Redis) inbound to Elasticache from Remote Support."

  security_group_id = aws_security_group.elasticache.id
}

resource "aws_security_group_rule" "elasticache_allow_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from Elasticache instances."
  security_group_id = aws_security_group.elasticache.id
}