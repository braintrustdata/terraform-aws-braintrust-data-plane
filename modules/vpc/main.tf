data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
  ssm_vpc_endpoint_services = {
    "ssm" : "com.amazonaws.${data.aws_region.current.region}.ssm",
    "ssmmessages" : "com.amazonaws.${data.aws_region.current.region}.ssmmessages",
    "ec2messages" : "com.amazonaws.${data.aws_region.current.region}.ec2messages",
  }

  s3_vpc_endpoint_has_org_ids     = length(var.s3_vpc_endpoint_resource_org_ids) > 0
  s3_vpc_endpoint_has_account_ids = length(var.s3_vpc_endpoint_resource_account_ids) > 0
  s3_vpc_endpoint_restricted      = local.s3_vpc_endpoint_has_org_ids || local.s3_vpc_endpoint_has_account_ids

  # Always include this account so module-owned buckets keep working (org and/or account mode).
  s3_vpc_endpoint_account_ids = distinct(concat(
    var.s3_vpc_endpoint_resource_account_ids,
    [data.aws_caller_identity.current.account_id]
  ))

  # Org and account allowlists compose (union of Allows), so cross-org export destinations
  # can be allowlisted by account even when org IDs are also set.
  s3_vpc_endpoint_customer_statements = !local.s3_vpc_endpoint_restricted ? [
    {
      Effect    = "Allow"
      Action    = ["s3:*"]
      Principal = "*"
      Resource  = ["*"]
    }
    ] : concat(
    local.s3_vpc_endpoint_has_org_ids ? [
      {
        Sid       = "AllowS3InAllowedOrganizations"
        Effect    = "Allow"
        Action    = ["s3:*"]
        Principal = "*"
        Resource  = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceOrgID" = var.s3_vpc_endpoint_resource_org_ids
          }
        }
      }
    ] : [],
    [
      {
        Sid       = "AllowS3InAllowedAccounts"
        Effect    = "Allow"
        Action    = ["s3:*"]
        Principal = "*"
        Resource  = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = local.s3_vpc_endpoint_account_ids
          }
        }
      }
    ]
  )

  # Amazon-owned buckets needed when restricted:
  # - ECR starport: private ECR layer pulls (defaults use public.ecr.aws over NAT/CloudFront;
  #   this covers private ECR / custom container_image overrides).
  # - CloudWatch agent: Brainstore user-data .deb from s3.amazonaws.com/amazoncloudwatch-agent/...
  s3_vpc_endpoint_aws_service_statements = local.s3_vpc_endpoint_restricted ? [
    {
      Sid       = "AllowECRStarportLayerBucket"
      Effect    = "Allow"
      Action    = ["s3:GetObject"]
      Principal = "*"
      Resource  = ["arn:aws:s3:::prod-${data.aws_region.current.region}-starport-layer-bucket/*"]
    },
    {
      Sid       = "AllowCloudWatchAgentBucket"
      Effect    = "Allow"
      Action    = ["s3:GetObject"]
      Principal = "*"
      Resource  = ["arn:aws:s3:::amazoncloudwatch-agent/*"]
    }
  ] : []

  s3_vpc_endpoint_statements = concat(
    local.s3_vpc_endpoint_customer_statements,
    local.s3_vpc_endpoint_aws_service_statements
  )
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}"
  }, local.common_tags)

  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-gateway"
  }, local.common_tags)
}

resource "aws_eip" "nat_public_ip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-nat-eip"
  }, local.common_tags)
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_public_ip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.internet_gateway]

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-nat"
  }, local.common_tags)
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-public-rt"
  }, local.common_tags)
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-private-rt"
  }, local.common_tags)
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = var.public_subnet_1_az
  map_public_ip_on_launch = false

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-public-subnet-1"
  }, local.common_tags)

  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = var.private_subnet_1_az

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-private-subnet-1"
  }, local.common_tags)

  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = var.private_subnet_2_az

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-private-subnet-2"
  }, local.common_tags)

  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "aws_subnet" "private_subnet_3" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_3_cidr
  availability_zone = var.private_subnet_3_az

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-private-subnet-3"
  }, local.common_tags)

  lifecycle {
    ignore_changes = [cidr_block]
  }
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_3_association" {
  subnet_id      = aws_subnet.private_subnet_3.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "public_subnet_1_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet_1.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_route_table.id]

  policy = jsonencode({ # nosemgrep
    Version   = "2012-10-17",
    Statement = local.s3_vpc_endpoint_statements
  })

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-s3-endpoint"
  }, local.common_tags)
}

resource "aws_security_group" "vpc_endpoints_tls" {
  count       = var.enable_brainstore_ec2_ssm ? 1 : 0
  name        = "${var.deployment_name}-${var.vpc_name}-vpc-endpoints"
  description = "Allow TLS inbound traffic from within VPC"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_vpc_endpoint" "ec2_ssm_endpoint" {
  for_each          = var.enable_brainstore_ec2_ssm ? local.ssm_vpc_endpoint_services : {}
  vpc_id            = aws_vpc.vpc.id
  service_name      = each.value
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.vpc_endpoints_tls[0].id,
  ]

  private_dns_enabled = true
  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id,
    aws_subnet.private_subnet_3.id,
  ]

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-${each.key}-endpoint"
  }, local.common_tags)
}
