
# Accept a VPC peering request from another VPC.
resource "aws_vpc_peering_connection_accepter" "accepter" {
  vpc_peering_connection_id = var.vpc_peering_connection_id
  auto_accept               = true

  tags = merge({
    Name = "braintrust-peer-accepter"
  }, var.custom_tags)
}

resource "aws_vpc_peering_connection_options" "accept-dns" {
  vpc_peering_connection_id = var.vpc_peering_connection_id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

# Add a route to the source route tables to allow communication with the destination VPC
resource "aws_route" "requester_to_accepter" {
  for_each                  = toset(var.source_route_table_ids)
  route_table_id            = each.value
  destination_cidr_block    = var.destination_cidr
  vpc_peering_connection_id = var.vpc_peering_connection_id
}
