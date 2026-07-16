# Subnet AZ lookups for filtering CloudFront VPC-origin-unsupported zones.
# Only needed for existing-VPC deploys (create_vpc=false), where subnet IDs are
# known literals. create_vpc=true uses AZ name locals instead — looking up
# module-created subnet IDs here would fail plan with "Invalid for_each".
data "aws_subnet" "private" {
  for_each = var.create_vpc ? toset([]) : toset([
    var.existing_private_subnet_1_id,
    var.existing_private_subnet_2_id,
    var.existing_private_subnet_3_id,
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

resource "terraform_data" "api_ecs_subnet_validation" {
  count = local.create_ecs_api ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.api_ecs_subnet_ids) >= 2
      error_message = "ECS API (CloudFront ApiEcsOrigin) requires at least 2 private subnets in CloudFront VPC origin supported availability zones. Excluded zone IDs: ${join(", ", local.cloudfront_vpc_origin_excluded_zone_ids)}."
    }
  }
}
