# Execution roles for the Lambda functions in modules/services, including the
# quarantine pruner and warmup roles. The services module exists whenever
# external EKS is off. Each role has its own count that combines create_iam
# with that gate. The AIProxy invoke role and the APIHandler Lambda policy are
# in iam-lambda-path.tf.

# Dedicated execution role for AutomationCron so it does not share the broad APIHandlerRole.
resource "aws_iam_role" "automation_cron" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = local.role_names.automation_cron

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags

  lifecycle {
    precondition {
      condition     = local.kms_key_arn != null && var.created_resources.code_bundle_s3_bucket_arn != null
      error_message = "The AutomationCron role needs the KMS key and code bundle bucket ARNs. Pass them in created_resources or kms_key_arn."
    }
  }
}

resource "aws_iam_role_policy_attachment" "automation_cron_vpc_access" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  role       = aws_iam_role.automation_cron[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "automation_cron_topic_map_report_read" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = "${var.deployment_name}-AutomationCronTopicMapReportRead"
  role = aws_iam_role.automation_cron[0].id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "TopicMapReportRead"
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = "${var.created_resources.code_bundle_s3_bucket_arn}/bundles/topic_maps/*/*.report.json"
      },
      # The code bundle bucket uses SSE-KMS with this key.
      {
        Sid      = "TopicMapReportDecrypt"
        Action   = ["kms:Decrypt"]
        Effect   = "Allow"
        Resource = local.kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "quarantine_pruner" {
  count = var.create_iam && local.create_lambda_services && var.enable_quarantine_pruner ? 1 : 0

  name = local.role_names.quarantine_pruner

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "quarantine_pruner_vpc_access" {
  count = var.create_iam && local.create_lambda_services && var.enable_quarantine_pruner ? 1 : 0

  role       = aws_iam_role.quarantine_pruner[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Quarantine functions are created at runtime, so their names are not known
# here. The tag condition limits the pruner to them.
resource "aws_iam_role_policy" "quarantine_pruner_delete_versions" {
  count = var.create_iam && local.create_lambda_services && var.enable_quarantine_pruner ? 1 : 0

  name = "${var.deployment_name}-QuarantinePrunerDeleteVersions"
  role = aws_iam_role.quarantine_pruner[0].id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "ListQuarantineFunctionVersions"
        Action = [
          "lambda:ListVersionsByFunction",
          "lambda:ListAliases",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustQuarantine" = "true"
          }
        }
      },
      {
        # A qualified ARN (function:name:version) only, so an unqualified
        # DeleteFunction cannot remove a whole function.
        Sid      = "DeleteQuarantineFunctionVersions"
        Action   = ["lambda:DeleteFunction"]
        Effect   = "Allow"
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:*:*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustQuarantine" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "default" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = local.role_names.default

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "default_vpc_access" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  role       = aws_iam_role.default[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "default" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = "${var.deployment_name}-DefaultRolePolicy"
  role = aws_iam_role.default[0].id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["elasticache:DescribeCacheClusters"]
        Effect   = "Allow"
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustDeploymentName" = var.deployment_name
          }
        }
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = [
          # Old naming scheme
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:*",
          # New naming scheme
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/*:*",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_role" "billing_cron" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = local.role_names.billing_cron

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "billing_cron_vpc_access" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  role       = aws_iam_role.billing_cron[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "catchup_etl" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = local.role_names.catchup_etl

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "catchup_etl_vpc_access" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  role       = aws_iam_role.catchup_etl[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "migrate_database" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = local.role_names.migrate_database

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "migrate_database_vpc_access" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  role       = aws_iam_role.migrate_database[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "quarantine_warmup" {
  count = var.create_iam && local.create_lambda_services && var.enable_quarantine_vpc ? 1 : 0

  name = local.role_names.quarantine_warmup

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  permissions_boundary = var.permissions_boundary_arn
  tags                 = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "quarantine_warmup_vpc_access" {
  count = var.create_iam && local.create_lambda_services && var.enable_quarantine_vpc ? 1 : 0

  role       = aws_iam_role.quarantine_warmup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "quarantine_warmup" {
  count = var.create_iam && local.create_lambda_services && var.enable_quarantine_vpc ? 1 : 0

  name = "${var.deployment_name}-QuarantineWarmupPolicy"
  role = aws_iam_role.quarantine_warmup[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateQuarantine"
        Effect   = "Allow"
        Action   = "lambda:CreateFunction"
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:Quarantine-*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/BraintrustQuarantine" = "true"
            "lambda:VpcIds"                       = local.quarantine_vpc_id
          }
        }
      },
      {
        Sid      = "TagQuarantine"
        Effect   = "Allow"
        Action   = "lambda:TagResource"
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:Quarantine-*"
        Condition = {
          StringEquals = { "aws:RequestTag/BraintrustQuarantine" = "true" }
        }
      },
      {
        Sid      = "ReadQuarantine"
        Effect   = "Allow"
        Action   = "lambda:GetFunction"
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:Quarantine-*"
        Condition = {
          StringEquals = { "aws:ResourceTag/BraintrustQuarantine" = "true" }
        }
      },
      {
        Sid      = "PassQuarantineRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.quarantine_function[0].arn
        Condition = {
          StringEquals = { "iam:PassedToService" = "lambda.amazonaws.com" }
        }
      },
      {
        Sid      = "DescribeQuarantineNetwork"
        Effect   = "Allow"
        Action   = ["ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs"]
        Resource = "*"
      }
    ]
  })

  lifecycle {
    precondition {
      condition     = local.quarantine_vpc_id != null
      error_message = "The quarantine warmup policy needs the quarantine VPC ID. Pass it in created_resources or existing_quarantine_vpc_id."
    }
  }
}
