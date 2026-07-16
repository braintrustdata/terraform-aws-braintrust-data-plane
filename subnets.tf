data "aws_subnet" "private" {
  for_each = toset([
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id,
  ])

  id = each.value
}

resource "terraform_data" "gateway_alb_subnet_validation" {
  count = local.create_ai_gateway && var.use_private_ai_gateway_origin ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.gateway_alb_subnet_ids) >= 2
      error_message = "use_private_ai_gateway_origin requires at least 2 private subnets in CloudFront VPC origin supported availability zones. Excluded zone IDs: ${join(", ", local.cloudfront_vpc_origin_excluded_zone_ids)}."
    }
  }
}
