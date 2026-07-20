data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_availability_zones" "available_for_vpc_origin" {
  state            = "available"
  exclude_zone_ids = local.cloudfront_vpc_origin_excluded_zone_ids
}
