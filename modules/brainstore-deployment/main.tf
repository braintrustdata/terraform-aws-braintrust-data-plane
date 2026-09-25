data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  function_name = "${var.deployment_name}-BrainstoreDeployment"
  artifact_tag  = jsondecode(file("${path.module}/VERSIONS.json"))["brainstore_deployment"]
  asset_bucket  = "braintrust-assets-${data.aws_region.current.region}"
  common_tags   = merge(var.custom_tags, { BraintrustDeploymentName = var.deployment_name })
  deployment = {
    schema_version  = 1
    deployment_name = var.deployment_name
    fleets          = var.fleets
  }
  asg_arns = [for fleet in var.fleets : "arn:${data.aws_partition.current.partition}:autoscaling:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${fleet.asg_name}"]
}

data "http" "artifact" {
  url                = "https://${local.asset_bucket}.s3.${data.aws_region.current.region}.amazonaws.com/lambda/BrainstoreDeployment/version-${local.artifact_tag}"
  request_timeout_ms = 10000
  retry {
    attempts     = 5
    min_delay_ms = 500
    max_delay_ms = 5000
  }
  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && can(regex("^lambda/BrainstoreDeployment/versions/[a-f0-9]+\\.zip$", trimspace(self.response_body)))
      error_message = "The pinned BrainstoreDeployment artifact must be published in this region before using this module release."
    }
  }
}

resource "aws_cloudwatch_log_group" "waiter" {
  name              = "/braintrust/${var.deployment_name}/${local.function_name}"
  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_iam_role" "waiter" {
  name                 = "${var.deployment_name}-brainstore-deployment"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "waiter" {
  role = aws_iam_role.waiter.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeInstanceRefreshes",
          "ec2:DescribeInstances",
          "elasticloadbalancing:DescribeTargetHealth",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "autoscaling:StartInstanceRefresh"
        Resource = local.asg_arns
        Condition = {
          StringEquals = { "autoscaling:ResourceTag/BraintrustDeploymentName" = var.deployment_name }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.waiter.arn}:*"
      },
    ]
  })
}

resource "aws_lambda_function" "waiter" {
  function_name = local.function_name
  role          = aws_iam_role.waiter.arn
  s3_bucket     = local.asset_bucket
  s3_key        = trimspace(data.http.artifact.response_body)
  runtime       = "nodejs22.x"
  architectures = ["arm64"]
  handler       = "index.handler"
  memory_size   = 256
  timeout       = 660
  publish       = true
  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.waiter.name
  }
  tags       = local.common_tags
  depends_on = [aws_iam_role_policy.waiter]
}
