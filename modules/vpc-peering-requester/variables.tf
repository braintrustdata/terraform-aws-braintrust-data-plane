variable "destination_account_id" {
  type        = string
  description = "The account ID of the destination VPC you will be requesting to peer with"
}

variable "destination_vpc_id" {
  type        = string
  description = "The ID of the destination VPC you will be requesting to peer with"
}

variable "destination_cidr" {
  type        = string
  description = "The CIDR block of the destination VPC you will be requesting to peer with. This can not overlap with your own VPC CIDR block."
}

variable "destination_region" {
  type        = string
  description = "The region of the destination VPC you will be requesting to peer with"
}

variable "source_vpc_id" {
  type        = string
  description = "The ID of your VPC"
}

variable "source_route_table_ids" {
  type        = list(string)
  description = "The IDs of the route tables in your VPC that you want to be able to communicate with the destination VPC"
}

variable "initiate_request_only" {
  type        = bool
  description = "Just initiate the request for the peer to accept it. Set this the first time you run, and then set it to false after the peer has accepted the request."
  default     = true
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
