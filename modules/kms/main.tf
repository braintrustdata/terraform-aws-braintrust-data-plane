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
          Sid    = "AllowAccountIAMPermissions"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action   = "kms:*"
          Resource = "*"
        },
        {
          Sid    = "AllowAutoScalingUseOfKey"
          Effect = "Allow"
          Principal = {
            AWS = [
              data.aws_iam_role.autoscaling_service_linked_role.arn
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
          Sid    = "AllowEC2UseOfKey"
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
          Sid    = "AllowAttachmentOfPersistentResources"
          Effect = "Allow"
          Principal = {
            AWS = [
              data.aws_iam_role.autoscaling_service_linked_role.arn
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
        },
        {
          Sid    = "AllowCloudWatchLogsUseOfKey"
          Effect = "Allow"
          Principal = {
            Service = "logs.${data.aws_region.current.region}.amazonaws.com"
          }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey",
          ]
          Resource = "*"
          Condition = {
            ArnLike = {
              "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
            }
          }
        },
        {
          Sid    = "AllowFlowLogsS3DeliveryUseOfKey"
          Effect = "Allow"
          Principal = {
            Service = "delivery.logs.amazonaws.com"
          }
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey",
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "aws:SourceAccount" : data.aws_caller_identity.current.account_id
            }
            ArnLike = {
              "aws:SourceArn" : "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
            }
          }
        },
        {
          Sid    = "AllowFargateGenerateDataKey"
          Effect = "Allow"
          Principal = {
            Service = "fargate.amazonaws.com"
          }
          Action = [
            "kms:GenerateDataKeyWithoutPlaintext",
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "kms:EncryptionContext:aws:ecs:clusterAccount" : data.aws_caller_identity.current.account_id
              "kms:EncryptionContext:aws:ecs:clusterName" : var.deployment_name
            }
          }
        },
        {
          Sid    = "AllowFargateCreateGrant"
          Effect = "Allow"
          Principal = {
            Service = "fargate.amazonaws.com"
          }
          Action = [
            "kms:CreateGrant",
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "kms:EncryptionContext:aws:ecs:clusterAccount" : data.aws_caller_identity.current.account_id
              "kms:EncryptionContext:aws:ecs:clusterName" : var.deployment_name
            }
            "ForAllValues:StringEquals" = {
              "kms:GrantOperations" : [
                "Decrypt",
              ]
            }
          }
        },
        {
          Sid    = "AllowFargateDescribeKey"
          Effect = "Allow"
          Principal = {
            Service = "fargate.amazonaws.com"
          }
          Action = [
            "kms:DescribeKey",
          ]
          Resource = "*"
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
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Account-owned prerequisite. Resolve it during planning so a fresh account
# fails before any resources are created, rather than at KMS CreateKey.
data "aws_iam_role" "autoscaling_service_linked_role" {
  name = "AWSServiceRoleForAutoScaling"

  lifecycle {
    postcondition {
      condition     = self.arn == "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      error_message = "The AWS Auto Scaling service-linked role must exist before creating the data-plane KMS key. Run scripts/create-service-linked-roles.sh with credentials for the target AWS account, then rerun terraform plan."
    }
  }
}
