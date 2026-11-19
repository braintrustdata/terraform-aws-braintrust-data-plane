locals {
  sandbox_subnets = var.create_sandbox_subnets ? {
    "1" = { id = aws_subnet.sandbox_private_subnet_1[0].id, cidr = cidrsubnet(var.vpc_cidr, 3, 4) }
    "2" = { id = aws_subnet.sandbox_private_subnet_2[0].id, cidr = cidrsubnet(var.vpc_cidr, 3, 5) }
    "3" = { id = aws_subnet.sandbox_private_subnet_3[0].id, cidr = cidrsubnet(var.vpc_cidr, 3, 6) }
  } : {}
  sandbox_runtime_subnets = var.create_sandbox_subnets ? {
    "1" = var.private_subnet_1_cidr
    "2" = var.private_subnet_2_cidr
    "3" = var.private_subnet_3_cidr
  } : {}
  sandbox_private_destinations = var.create_sandbox_subnets ? {
    "0" = var.vpc_cidr
    "1" = "10.0.0.0/8"
    "2" = "172.16.0.0/12"
    "3" = "192.168.0.0/16"
    "4" = "169.254.0.0/16"
    "5" = "100.64.0.0/10"
    "6" = "127.0.0.0/8"
  } : {}
}

resource "aws_network_acl" "sandbox" {
  count  = var.create_sandbox_subnets ? 1 : 0
  vpc_id = aws_vpc.vpc.id
  tags   = merge(local.common_tags, { Name = "${var.deployment_name}-sandbox" })
}

resource "aws_network_acl_association" "sandbox" {
  for_each       = local.sandbox_subnets
  network_acl_id = aws_network_acl.sandbox[0].id
  subnet_id      = each.value.id
}

# The cluster control plane, system nodes, workers and TLS endpoint share only
# these dedicated ranges. Security groups limit their individual connections.
resource "aws_network_acl_rule" "sandbox_cluster_ingress" {
  for_each       = local.sandbox_subnets
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 100 + tonumber(each.key)
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
}

resource "aws_network_acl_rule" "sandbox_cluster_egress" {
  for_each       = local.sandbox_subnets
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 100 + tonumber(each.key)
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
}

resource "aws_network_acl_rule" "sandbox_runtime_ingress" {
  for_each       = local.sandbox_runtime_subnets
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 200 + tonumber(each.key)
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value
  from_port      = 9400
  to_port        = 9400
}

resource "aws_network_acl_rule" "sandbox_proxy_egress" {
  for_each       = local.sandbox_runtime_subnets
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 200 + tonumber(each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value
  from_port      = 4002
  to_port        = 4002
}

# NACLs are stateless. Linux clients use this ephemeral range for replies on the
# runtime API and forward-proxy connections. SGs still authorize each caller.
resource "aws_network_acl_rule" "sandbox_runtime_return_ingress" {
  for_each       = local.sandbox_runtime_subnets
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 210 + tonumber(each.key)
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value
  from_port      = 32768
  to_port        = 65535
}

resource "aws_network_acl_rule" "sandbox_runtime_return_egress" {
  for_each       = local.sandbox_runtime_subnets
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 210 + tonumber(each.key)
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value
  from_port      = 32768
  to_port        = 65535
}

resource "aws_network_acl_rule" "sandbox_runtime_discovery_ingress" {
  for_each       = local.sandbox_runtime_subnets
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 220 + tonumber(each.key)
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "sandbox_private_ingress" {
  for_each       = local.sandbox_private_destinations
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 300 + tonumber(each.key)
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = each.value
}

resource "aws_network_acl_rule" "sandbox_private_egress" {
  for_each       = local.sandbox_private_destinations
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 300 + tonumber(each.key)
  egress         = true
  protocol       = "-1"
  rule_action    = "deny"
  cidr_block     = each.value
}

resource "aws_network_acl_rule" "sandbox_public_https" {
  count          = var.create_sandbox_subnets ? 1 : 0
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 400
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "sandbox_public_return" {
  count          = var.create_sandbox_subnets ? 1 : 0
  network_acl_id = aws_network_acl.sandbox[0].id
  rule_number    = 400
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  # The release Lambda uses the full Hyperplane ENI ephemeral port range.
  from_port = 1024
  to_port   = 65535
}
