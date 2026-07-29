# Same-account peering so quarantine Lambdas can reach the private gateway ALB
# on :80. Only when use_private_gateway_quarantine_proxy is on and both VPCs
# are created by this module — existing VPC / existing quarantine require
# manual peering. Do not peer when quarantine uses a manual/SaaS hosted URL.

locals {
  peer_quarantine_to_main = local.wire_quarantine_to_private_gateway && local.create_quarantine_vpc && var.create_vpc
}

resource "aws_vpc_peering_connection" "quarantine_to_main" {
  count = local.peer_quarantine_to_main ? 1 : 0

  vpc_id      = module.quarantine_vpc[0].vpc_id
  peer_vpc_id = module.main_vpc[0].vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge({
    Name = "${var.deployment_name}-quarantine-to-main"
  }, var.custom_tags)
}

resource "aws_route" "quarantine_private_to_main" {
  count = local.peer_quarantine_to_main ? 1 : 0

  route_table_id            = module.quarantine_vpc[0].private_route_table_id
  destination_cidr_block    = module.main_vpc[0].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.quarantine_to_main[0].id
}

resource "aws_route" "main_private_to_quarantine" {
  count = local.peer_quarantine_to_main ? 1 : 0

  route_table_id            = module.main_vpc[0].private_route_table_id
  destination_cidr_block    = var.quarantine_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.quarantine_to_main[0].id
}
