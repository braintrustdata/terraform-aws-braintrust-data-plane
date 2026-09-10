########################################
# VPC Encryption Control (optional)
########################################
# Enforces encryption in transit for traffic in this VPC. Disabled by default;
# the resource is created only when var.encryption_control is "monitor" or
# "enforce", which are passed straight through as the AWS mode:
#   monitor -> observe only, does not block unencrypted traffic
#   enforce -> require encryption in transit

locals {
  encryption_control_enabled = var.encryption_control != "disabled"

  # Null when disabled so downstream lookups do not fail.
  encryption_control_mode = local.encryption_control_enabled ? var.encryption_control : null
}

resource "aws_vpc_encryption_control" "vpc" {
  count = local.encryption_control_enabled ? 1 : 0

  vpc_id = aws_vpc.vpc.id
  mode   = local.encryption_control_mode

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-encryption-control"
  }, local.common_tags)
}
