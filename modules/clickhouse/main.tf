locals {
  clickhouse_bucket_name = var.external_clickhouse_s3_bucket_name == null ? aws_s3_bucket.clickhouse_s3_bucket[0].id : var.external_clickhouse_s3_bucket_name
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

data "aws_region" "current" {}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_subnet" "clickhouse_subnet" {
  id = var.clickhouse_subnet_id
}

# nosemgrep
resource "aws_instance" "clickhouse" {
  count                = var.clickhouse_instance_count
  ami                  = data.aws_ami.amazon_linux_2.id
  instance_type        = var.clickhouse_instance_type
  subnet_id            = var.clickhouse_subnet_id
  key_name             = var.clickhouse_instance_key_pair_name
  iam_instance_profile = aws_iam_instance_profile.clickhouse.name

  vpc_security_group_ids = var.clickhouse_security_group_ids

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 128
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
    tags = {
      Name = "${var.deployment_name}-clickhouse-root"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region                   = data.aws_region.current.region
    s3_bucket_name               = local.clickhouse_bucket_name
    clickhouse_secret_id         = aws_secretsmanager_secret.clickhouse_secret.arn
    clickhouse_secret_version_id = aws_secretsmanager_secret_version.clickhouse_secret.version_id
  }))

  tags = merge({
    Name = "${var.deployment_name}-clickhouse"
  }, local.common_tags)
}

# EBS volume for Clickhouse metadata. This needs to be preserved across instances.
resource "aws_ebs_volume" "clickhouse_metadata" {
  count             = var.clickhouse_instance_count
  availability_zone = data.aws_subnet.clickhouse_subnet.availability_zone
  size              = var.clickhouse_metadata_storage_size
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-clickhouse-metadata"
  }, local.common_tags)
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "clickhouse_metadata" {
  count       = var.clickhouse_instance_count
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.clickhouse_metadata[0].id
  instance_id = aws_instance.clickhouse[0].id

  # This is a workaround to ensure the volume is attached after the instance is created.
  depends_on = [aws_instance.clickhouse]
}
