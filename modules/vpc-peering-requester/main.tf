
# Create a VPC peering request to a destination VPC. The Destination account owner needs to accept the request.
resource "aws_vpc_peering_connection" "requester" {
  peer_owner_id = var.destination_account_id
  peer_vpc_id   = var.destination_vpc_id
  peer_region   = var.destination_region
  vpc_id        = var.source_vpc_id
  auto_accept   = false

  tags = merge({
    Name = "braintrust-peer-requester"
  }, var.custom_tags)
}

resource "aws_vpc_peering_connection_options" "accept-dns" {
  count                     = var.initiate_request_only ? 0 : 1
  vpc_peering_connection_id = aws_vpc_peering_connection.requester.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

# Add a route to the source route tables to allow communication with the destination VPC
resource "aws_route" "requester_to_accepter" {
  count                     = var.initiate_request_only ? 0 : length(var.source_route_table_ids)
  route_table_id            = var.source_route_table_ids[count.index]
  destination_cidr_block    = var.destination_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.requester.id
}
