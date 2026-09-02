data "aws_partition" "current" {}

locals {
  flow_log_enabled       = var.flow_log.enabled
  flow_log_is_cloudwatch = var.flow_log.destination_type == "cloud-watch-logs"
  flow_log_is_s3         = var.flow_log.destination_type == "s3"

  # An IAM role is always required to deliver flow logs to CloudWatch Logs,
  # whether the log group is module-managed or customer-provided.
  create_flow_log_role = local.flow_log_enabled && local.flow_log_is_cloudwatch

  # The module only manages the destination when the caller did not supply one.
  create_flow_log_log_group = local.flow_log_enabled && local.flow_log_is_cloudwatch && var.flow_log.destination_arn == null
  create_flow_log_bucket    = local.flow_log_enabled && local.flow_log_is_s3 && var.flow_log.destination_arn == null

  # try() so a disabled default (all null / count = 0) does not fail plan.
  # coalesce() itself errors when every argument is null.
  flow_log_destination_arn = try(
    coalesce(
      var.flow_log.destination_arn,
      try(aws_cloudwatch_log_group.flow_log[0].arn, null),
      try(aws_s3_bucket.flow_log[0].arn, null)
    ),
    null
  )

  flow_log_name = "${var.deployment_name}-${var.vpc_name}-flow-log"
}

resource "aws_flow_log" "vpc" {
  count = local.flow_log_enabled ? 1 : 0

  vpc_id                   = aws_vpc.vpc.id
  traffic_type             = var.flow_log.traffic_type
  log_destination_type     = var.flow_log.destination_type
  log_destination          = local.flow_log_destination_arn
  max_aggregation_interval = var.flow_log.max_aggregation_interval
  log_format               = var.flow_log.log_format
  iam_role_arn             = local.create_flow_log_role ? aws_iam_role.flow_log[0].arn : null

  tags = merge({
    Name = local.flow_log_name
  }, local.common_tags)

  depends_on = [
    aws_s3_bucket_policy.flow_log,
    aws_iam_role_policy_attachment.flow_log,
  ]
}

########################################
# CloudWatch Logs destination (optional)
########################################

resource "aws_cloudwatch_log_group" "flow_log" {
  count = local.create_flow_log_log_group ? 1 : 0

  name              = "/aws/vpc/flow-logs/${var.deployment_name}-${var.vpc_name}"
  retention_in_days = var.flow_log.retention_in_days
  kms_key_id        = var.flow_log.kms_key_arn

  tags = merge({
    Name = local.flow_log_name
  }, local.common_tags)
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  count = local.create_flow_log_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "flow_log" {
  count = local.create_flow_log_role ? 1 : 0

  name               = local.flow_log_name
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "flow_log" {
  count = local.create_flow_log_role ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${local.flow_log_destination_arn}:*"]
  }
}

resource "aws_iam_policy" "flow_log" {
  count = local.create_flow_log_role ? 1 : 0

  name   = local.flow_log_name
  policy = data.aws_iam_policy_document.flow_log[0].json
}

resource "aws_iam_role_policy_attachment" "flow_log" {
  count = local.create_flow_log_role ? 1 : 0

  role       = aws_iam_role.flow_log[0].name
  policy_arn = aws_iam_policy.flow_log[0].arn
}

########################################
# Module-managed S3 destination (optional)
########################################

resource "aws_s3_bucket" "flow_log" {
  count = local.create_flow_log_bucket ? 1 : 0

  bucket_prefix = "${var.deployment_name}-${var.vpc_name}-flow-"

  lifecycle {
    ignore_changes = [
      # S3 does not support renaming buckets
      bucket_prefix
    ]
  }

  tags = merge({
    Name = local.flow_log_name
  }, local.common_tags)
}

resource "aws_s3_bucket_ownership_controls" "flow_log" {
  count = local.create_flow_log_bucket ? 1 : 0

  bucket = aws_s3_bucket.flow_log[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_log" {
  count = local.create_flow_log_bucket ? 1 : 0

  bucket = aws_s3_bucket.flow_log[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.flow_log.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.flow_log.kms_key_arn
    }
    bucket_key_enabled = var.flow_log.kms_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "flow_log" {
  count = local.create_flow_log_bucket ? 1 : 0

  bucket = aws_s3_bucket.flow_log[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_log" {
  count = local.create_flow_log_bucket ? 1 : 0

  bucket = aws_s3_bucket.flow_log[0].id

  rule {
    id     = "expire-flow-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.flow_log.retention_in_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "flow_log_bucket" {
  count = local.create_flow_log_bucket ? 1 : 0

  statement {
    sid     = "AWSLogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.flow_log[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }

  statement {
    sid       = "AWSLogDeliveryAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.flow_log[0].arn]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.flow_log[0].arn,
      "${aws_s3_bucket.flow_log[0].arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "flow_log" {
  count = local.create_flow_log_bucket ? 1 : 0

  bucket = aws_s3_bucket.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log_bucket[0].json

  depends_on = [aws_s3_bucket_ownership_controls.flow_log]
}
