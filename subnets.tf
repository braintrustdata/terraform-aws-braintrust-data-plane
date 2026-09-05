# Subnet AZ lookups for filtering CloudFront VPC-origin-unsupported zones.
# Only needed for existing-VPC deploys (create_vpc=false), where subnet IDs are
# known literals. create_vpc=true uses AZ name locals instead — looking up
# module-created subnet IDs here would fail plan with "Invalid for_each".
data "aws_subnet" "private" {
  for_each = var.create_vpc ? {} : {
    "1" = var.existing_private_subnet_1_id
    "2" = var.existing_private_subnet_2_id
    "3" = var.existing_private_subnet_3_id
  }

  id = each.value
}

locals {
  requires_cloudfront_vpc_origin_subnet_validation = (
    local.create_ecs_api ||
    (local.create_ai_gateway && var.use_private_ai_gateway_origin) ||
    local.create_loop_runtime
  )
}

check "cloudfront_vpc_origin_subnet_validation" {
  assert {
    condition     = !local.requires_cloudfront_vpc_origin_subnet_validation || length(local.cloudfront_vpc_origin_safe_zone_ids) >= 2
    error_message = "CloudFront VPC origins require at least 2 private subnets in supported availability zones. Excluded zone IDs: ${join(", ", local.cloudfront_vpc_origin_excluded_zone_ids)}."
  }

  assert {
    condition = (
      !local.requires_cloudfront_vpc_origin_subnet_validation ||
      length(local.cloudfront_vpc_origin_safe_zone_ids) == length(distinct(local.cloudfront_vpc_origin_safe_zone_ids))
    )
    error_message = "CloudFront VPC origin subnets must span distinct availability zones. Duplicate private_subnet_*_az values are not supported."
  }
}
