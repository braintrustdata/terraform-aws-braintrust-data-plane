########################################
# VPC Encryption Control (optional)
########################################
# Enforces encryption in transit for traffic in this VPC. Disabled by default;
# the resource is created only when var.encryption_control_mode is set to
# "monitor" or "enforce", which is passed straight through as the AWS mode:
#   monitor -> observe only, does not block unencrypted traffic
#   enforce -> require encryption in transit

locals {
  encryption_control_enabled = var.encryption_control_mode != null
}

resource "aws_vpc_encryption_control" "vpc" {
  count = local.encryption_control_enabled ? 1 : 0

  vpc_id = aws_vpc.vpc.id
  mode   = var.encryption_control_mode

  tags = merge({
    Name = "${var.deployment_name}-${var.vpc_name}-encryption-control"
  }, local.common_tags)
}
