locals {
  observability_deployment_name = "evignanker-sb"
  observability_source_dir      = "/Users/brain_eugenevignanker/Workspace/area3/observability"
  observability_package_key     = "observability/${local.observability_deployment_name}/observability.zip"
  observability_private_ip      = "10.175.1.18"
  observability_otlp_endpoint   = "http://${local.observability_private_ip}:4318"
  observability_brainstore_env_vars = var.enable_observability ? {
    BRAINSTORE_OTLP_HTTP_ENDPOINT = local.observability_otlp_endpoint
    BRAINSTORE_OTLP_TELEMETRY     = "logs,metrics,traces"
  } : {}
  observability_tags = {
    Name                     = "${local.observability_deployment_name}-observability"
    BraintrustDeploymentName = local.observability_deployment_name
    Owner                    = "Eugene Vignanker"
    Team                     = "Brainstore"
  }
}

data "aws_region" "current" {}

data "archive_file" "observability_package" {
  count       = var.enable_observability ? 1 : 0
  type        = "zip"
  source_dir  = local.observability_source_dir
  output_path = "${path.module}/.terraform/observability.zip"
}

resource "aws_s3_object" "observability_package" {
  count  = var.enable_observability ? 1 : 0
  bucket = module.braintrust-data-plane.code_bundle_s3_bucket_name
  key    = local.observability_package_key
  source = data.archive_file.observability_package[0].output_path
  etag   = data.archive_file.observability_package[0].output_md5

  tags = local.observability_tags
}

resource "aws_security_group" "observability" {
  count       = var.enable_observability ? 1 : 0
  name        = "${local.observability_deployment_name}-observability"
  description = "Observability host for the sandbox Brainstore deployment"
  vpc_id      = module.braintrust-data-plane.main_vpc_id

  tags = local.observability_tags
}

resource "aws_vpc_security_group_ingress_rule" "observability_otlp_grpc_from_brainstore" {
  count                        = var.enable_observability ? 1 : 0
  security_group_id            = aws_security_group.observability[0].id
  referenced_security_group_id = module.braintrust-data-plane.brainstore_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 4317
  to_port                      = 4317
  description                  = "OTLP gRPC from Brainstore instances"
}

resource "aws_vpc_security_group_ingress_rule" "observability_otlp_http_from_brainstore" {
  count                        = var.enable_observability ? 1 : 0
  security_group_id            = aws_security_group.observability[0].id
  referenced_security_group_id = module.braintrust-data-plane.brainstore_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 4318
  to_port                      = 4318
  description                  = "OTLP HTTP from Brainstore instances"
}

resource "aws_vpc_security_group_egress_rule" "observability_all_egress" {
  count             = var.enable_observability ? 1 : 0
  security_group_id = aws_security_group.observability[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow package installs, image pulls, and AWS API access"
}

data "aws_ami" "observability_ubuntu_24_04" {
  count       = var.enable_observability ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-*-24.04-*-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

data "aws_iam_policy_document" "observability_assume_role" {
  count = var.enable_observability ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "observability" {
  count              = var.enable_observability ? 1 : 0
  name               = "${local.observability_deployment_name}-observability"
  assume_role_policy = data.aws_iam_policy_document.observability_assume_role[0].json
  tags               = local.observability_tags
}

resource "aws_iam_role_policy_attachment" "observability_ssm" {
  count      = var.enable_observability ? 1 : 0
  role       = aws_iam_role.observability[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "observability_package_read" {
  count = var.enable_observability ? 1 : 0

  statement {
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${module.braintrust-data-plane.code_bundle_s3_bucket_name}/${aws_s3_object.observability_package[0].key}",
    ]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [module.braintrust-data-plane.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "observability_package_read" {
  count  = var.enable_observability ? 1 : 0
  name   = "observability-package-read"
  role   = aws_iam_role.observability[0].id
  policy = data.aws_iam_policy_document.observability_package_read[0].json
}

resource "aws_iam_instance_profile" "observability" {
  count = var.enable_observability ? 1 : 0
  name  = "${local.observability_deployment_name}-observability"
  role  = aws_iam_role.observability[0].name
  tags  = local.observability_tags
}

resource "aws_instance" "observability" {
  count                       = var.enable_observability ? 1 : 0
  ami                         = data.aws_ami.observability_ubuntu_24_04[0].id
  instance_type               = "t4g.large"
  subnet_id                   = module.braintrust-data-plane.main_vpc_private_subnet_1_id
  private_ip                  = local.observability_private_ip
  vpc_security_group_ids      = [aws_security_group.observability[0].id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.observability[0].name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/observability-user-data.sh.tpl", {
    aws_region              = data.aws_region.current.region
    observability_bucket    = module.braintrust-data-plane.code_bundle_s3_bucket_name
    observability_key       = aws_s3_object.observability_package[0].key
    observability_zip_sha   = data.archive_file.observability_package[0].output_base64sha256
    observability_stack_dir = "/opt/braintrust-observability"
  })

  root_block_device {
    volume_size           = 500
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = module.braintrust-data-plane.kms_key_arn
    delete_on_termination = true

    tags = local.observability_tags
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  tags = local.observability_tags
}
