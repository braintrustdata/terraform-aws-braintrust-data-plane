variable "destination_cidr" {
  type        = string
  description = "The CIDR block of the destination VPC you will be peered with. This can not overlap with your own VPC CIDR block."
}

variable "source_route_table_ids" {
  type        = list(string)
  description = "The IDs of the route tables in your VPC that you want to be able to communicate with the destination VPC"
}

variable "vpc_peering_connection_id" {
  type        = string
  description = "The ID of the VPC peering connection to accept. You need to get this from the requester."
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
