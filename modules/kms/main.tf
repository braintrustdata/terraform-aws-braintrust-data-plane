resource "aws_kms_key" "braintrust" {
  description             = "KMS key for encrypting resources in the Braintrust data plane"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "Enable IAM User Permissions"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action   = "kms:*"
          Resource = "*"
        },
        {
          Sid    = "Allow Auto Scaling service to use the key"
          Effect = "Allow"
          Principal = {
            AWS = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
            ]
          }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey",
          ],
          Resource = "*"
        },
        {
          Sid    = "Allow EC2 service to use the key"
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
          ],
          Resource = "*"
        },
        {
          Sid    = "Allow CloudWatch Logs to use the key"
          Effect = "Allow"
          Principal = {
            Service = "logs.${data.aws_region.current.name}.amazonaws.com"
          }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey",
            "kms:CreateGrant"
          ]
          Resource = "*"
          Condition = {
            ArnLike = {
              "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
            }
          }
        },
        {
          Sid    = "Allow attachment of persistent resources"
          Effect = "Allow"
          Principal = {
            AWS = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
            ]
          }
          Action = [
            "kms:CreateGrant"
          ],
          Resource = "*",
          Condition = {
            Bool = {
              "kms:GrantIsForAWSResource" : true
            }
          }
        }
      ],
      var.additional_key_policies
    )
  })

  tags = merge({
    Name                     = "${var.deployment_name}-main"
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

resource "aws_kms_alias" "braintrust" {
  name          = "alias/braintrust/${var.deployment_name}"
  target_key_id = aws_kms_key.braintrust.key_id
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
