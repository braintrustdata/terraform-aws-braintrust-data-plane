data "aws_region" "current" {}

locals {
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }
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
  map_public_ip_on_launch = true

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
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_route_table.id]

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = ["s3:*"],
        Principal = "*",
        Resource  = ["*"]
      }
    ]
  })

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-s3-endpoint"
  }, local.common_tags)
}
