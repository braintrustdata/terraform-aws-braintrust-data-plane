resource "aws_security_group" "system" {
  name        = "${var.deployment_name}-sandbox-system"
  description = "Sandbox Service system nodes and release installer"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

resource "aws_security_group" "workers" {
  name        = "${var.deployment_name}-sandbox-workers"
  description = "Sandbox workers with explicit private service access"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

resource "aws_security_group" "public_egress" {
  name        = "${var.deployment_name}-sandbox-public-egress"
  description = "Additional public IPv4 destinations for sandbox nodes"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

resource "aws_security_group" "secrets_manager" {
  name        = "${var.deployment_name}-sandbox-secrets-endpoint"
  description = "Private TLS bundle access for the Sandbox Service installer"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "secrets_manager_from_system" {
  security_group_id            = aws_security_group.secrets_manager.id
  referenced_security_group_id = aws_security_group.system.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "TLS bundle reads from the release installer"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "system_to_secrets_manager" {
  security_group_id            = aws_security_group.system.id
  referenced_security_group_id = aws_security_group.secrets_manager.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Private Secrets Manager access"
  tags                         = local.common_tags
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.secrets_manager.id]
  private_dns_enabled = false
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.release.arn }
      Action    = "secretsmanager:GetSecretValue"
      Resource  = [aws_secretsmanager_secret.server_tls.arn, aws_secretsmanager_secret.client_tls.arn]
    }]
  })
  tags = local.common_tags
}

resource "aws_ec2_managed_prefix_list" "public_ipv4" {
  for_each = {
    first  = slice(local.public_ipv4_cidrs, 0, 52)
    second = slice(local.public_ipv4_cidrs, 52, 103)
  }
  name           = "${var.deployment_name}-sandbox-public-${each.key}"
  address_family = "IPv4"
  max_entries    = length(each.value)
  dynamic "entry" {
    for_each = each.value
    content {
      cidr = entry.value
    }
  }
  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "system_public" {
  security_group_id = aws_security_group.system.id
  prefix_list_id    = aws_ec2_managed_prefix_list.public_ipv4["first"].id
  ip_protocol       = "-1"
  description       = "Public image registries and AWS APIs"
  tags              = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "workers_public" {
  security_group_id = aws_security_group.workers.id
  prefix_list_id    = aws_ec2_managed_prefix_list.public_ipv4["first"].id
  ip_protocol       = "-1"
  description       = "Public image registries; sandbox network policy is enforced by the worker"
  tags              = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "additional_public" {
  security_group_id = aws_security_group.public_egress.id
  prefix_list_id    = aws_ec2_managed_prefix_list.public_ipv4["second"].id
  ip_protocol       = "-1"
  description       = "Remaining public IPv4 destinations"
  tags              = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "cluster_from_nodes" {
  for_each = {
    "System nodes" = aws_security_group.system.id
    "Workers"      = aws_security_group.workers.id
  }
  security_group_id            = aws_eks_cluster.sandbox.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = each.value
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Kubernetes API access from ${each.key}"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "nodes_to_cluster" {
  for_each = {
    system  = aws_security_group.system.id
    workers = aws_security_group.workers.id
  }
  security_group_id            = each.value
  referenced_security_group_id = aws_eks_cluster.sandbox.vpc_config[0].cluster_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Private Kubernetes API"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_cluster" {
  for_each = {
    system  = aws_security_group.system.id
    workers = aws_security_group.workers.id
  }
  security_group_id            = each.value
  referenced_security_group_id = aws_eks_cluster.sandbox.vpc_config[0].cluster_security_group_id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Kubelet access from the control plane"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "system_dns" {
  for_each = {
    "system TCP" = { protocol = "tcp", group = aws_security_group.system.id }
    "system UDP" = { protocol = "udp", group = aws_security_group.system.id }
    "worker TCP" = { protocol = "tcp", group = aws_security_group.workers.id }
    "worker UDP" = { protocol = "udp", group = aws_security_group.workers.id }
  }
  security_group_id            = aws_security_group.system.id
  referenced_security_group_id = each.value.group
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = each.value.protocol
  description                  = "Cluster DNS from ${each.key}"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "system_dns" {
  for_each                     = toset(["tcp", "udp"])
  security_group_id            = aws_security_group.system.id
  referenced_security_group_id = aws_security_group.system.id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = each.value
  description                  = "System node cluster DNS"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "worker_dns" {
  for_each                     = toset(["tcp", "udp"])
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.system.id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = each.value
  description                  = "Worker cluster DNS"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "workers_from_controller" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.system.id
  from_port                    = 9400
  to_port                      = 9400
  ip_protocol                  = "tcp"
  description                  = "Sandbox controller mTLS access"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "controller_to_workers" {
  security_group_id            = aws_security_group.system.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = 9400
  to_port                      = 9400
  ip_protocol                  = "tcp"
  description                  = "Sandbox controller mTLS access"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "workers_from_authorized_security_groups" {
  for_each                     = var.authorized_security_groups
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = each.value
  from_port                    = 9400
  to_port                      = 9400
  ip_protocol                  = "tcp"
  description                  = "Sandbox mTLS access from ${each.key}"
  tags                         = local.common_tags
}
