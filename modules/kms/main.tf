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

locals {
  # The key and alias attributes the freeze guard protects. The arguments that
  # force key replacement are included so a configured replacement fails at
  # plan time; otherwise only the unknown new key_id would differ and the guard
  # would fail at apply, after the replacement.
  kms_key_freeze_protected = {
    policy                   = aws_kms_key.braintrust.policy
    description              = aws_kms_key.braintrust.description
    is_enabled               = aws_kms_key.braintrust.is_enabled
    enable_key_rotation      = aws_kms_key.braintrust.enable_key_rotation
    rotation_period_in_days  = aws_kms_key.braintrust.rotation_period_in_days
    tags                     = aws_kms_key.braintrust.tags
    tags_all                 = aws_kms_key.braintrust.tags_all
    region                   = aws_kms_key.braintrust.region
    key_usage                = aws_kms_key.braintrust.key_usage
    customer_master_key_spec = aws_kms_key.braintrust.customer_master_key_spec
    multi_region             = aws_kms_key.braintrust.multi_region
    custom_key_store_id      = aws_kms_key.braintrust.custom_key_store_id
    xks_key_id               = aws_kms_key.braintrust.xks_key_id
    key_id                   = aws_kms_key.braintrust.key_id
    alias_name               = aws_kms_alias.braintrust.name
    alias_target_key_id      = aws_kms_alias.braintrust.target_key_id
  }
}

# Freeze guard. It stores the protected values when it's created and ignores
# later changes to its input, so self.output keeps the stored values. The
# postcondition compares them with the planned values and fails the plan when
# the configuration changes the key or alias. It doesn't use prevent_destroy,
# so terraform destroy still works. It doesn't catch out-of-band drift, a
# -replace or taint on the key, or a caller key policy that is unknown at plan
# time; MIGRATION_V8.md lists those.
resource "terraform_data" "kms_key_freeze" {
  count = var.enable_kms_key_freeze ? 1 : 0

  input = local.kms_key_freeze_protected

  lifecycle {
    ignore_changes = [input]

    postcondition {
      condition     = self.output == local.kms_key_freeze_protected
      error_message = "enable_kms_key_freeze is on and this plan changes the managed KMS key or alias. Restore the configuration, or for an agreed change set enable_kms_key_freeze = false, apply, then set it back to true against a plan with no key or alias changes. See MIGRATION_V8.md."
    }
  }
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
