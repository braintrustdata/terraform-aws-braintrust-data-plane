# The role used by the API handler and AI proxy. API ECS tasks use it as their
# task role, and the APIHandler and AIProxy Lambdas use it as their execution
# role.
locals {
  # Lambda runs this role only on the Lambda API path: external EKS off and
  # enable_ecs_api = false. ECS mode and external EKS don't trust Lambda. Both
  # terms are needed: create_lambda_services is false on external EKS, where
  # enable_ecs_api is also false, so the second term alone would keep Lambda there.
  api_handler_trust_statements = concat(
    local.create_lambda_services && !local.enable_ecs_api ? [
      {
        Sid    = "AllowLambdaAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ] : [],
    # IRSA trust relationship (cluster ARN is required)
    var.enable_eks_irsa && var.eks_cluster_arn != null ? [
      {
        Sid    = "AllowIRSAAssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.eks_oidc_issuer_url, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "${replace(local.eks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.eks_namespace != null ? var.eks_namespace : "*"}:*"
          }
          StringEquals = {
            "${replace(local.eks_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ] : [],
    # EKS Pod Identity trust relationship
    var.enable_eks_pod_identity ? [
      merge(
        {
          Sid    = "AllowEKSPodIdentityAssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "pods.eks.amazonaws.com"
          }
          Action = [
            "sts:AssumeRole",
            "sts:TagSession"
          ]
        },
        # Only include Condition block if at least one EKS restriction is provided
        var.eks_cluster_arn != null || var.eks_namespace != null ? {
          Condition = {
            StringEquals = merge(
              var.eks_cluster_arn != null ? {
                "aws:RequestTag/eks-cluster-arn" = [var.eks_cluster_arn]
              } : {},
              var.eks_namespace != null ? {
                "aws:RequestTag/kubernetes-namespace" = [var.eks_namespace]
              } : {}
            )
          }
        } : {}
      )
    ] : [],
    # ECS trust relationship
    local.create_ecs_api ? [
      {
        Sid    = "AllowECSTasksAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ] : []
  )
}

resource "aws_iam_role" "api_handler" {
  count = var.create_iam ? 1 : 0

  name = local.role_names.api_handler
  path = local.role_paths.api_handler
  assume_role_policy = var.override_api_iam_role_trust_policy != null ? var.override_api_iam_role_trust_policy : jsonencode({ # nosemgrep
    Version   = "2012-10-17"
    Statement = local.api_handler_trust_statements
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags

  lifecycle {
    # Some live stacks have older physical names.
    ignore_changes = [name]

    precondition {
      condition = !local.is_managed_call || alltrue([
        for arn in [
          local.kms_key_arn,
          var.created_resources.code_bundle_s3_bucket_arn,
          var.created_resources.lambda_responses_s3_bucket_arn,
        ] : arn != null
      ])
      error_message = "The shared API role needs the KMS key, code bundle bucket and Lambda responses bucket ARNs. Pass them in created_resources or kms_key_arn."
    }

    precondition {
      condition     = var.override_api_iam_role_trust_policy != null || length(local.api_handler_trust_statements) > 0
      error_message = "The shared API role's trust has no statements. External EKS needs a trust for it: set enable_eks_pod_identity = true, set enable_eks_irsa = true with existing_eks_cluster_arn (eks_cluster_arn when you call modules/iam directly), or set override_api_iam_role_trust_policy."
    }
  }
}

resource "aws_iam_role_policy_attachment" "api_handler" {
  count = var.create_iam ? 1 : 0

  role       = aws_iam_role.api_handler[0].name
  policy_arn = aws_iam_policy.api_handler[0].arn
}

resource "aws_iam_role_policy_attachment" "api_handler_additional_policy" {
  count = var.create_iam ? length(var.service_additional_policy_arns) : 0

  role       = aws_iam_role.api_handler[0].name
  policy_arn = var.service_additional_policy_arns[count.index]
}

resource "aws_iam_role_policy" "api_handler_cloudwatch_metrics" {
  count = var.create_iam && local.create_ecs_api ? 1 : 0

  name = "cloudwatch-autoscaling-metrics"
  role = aws_iam_role.api_handler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowPutMetricData"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Braintrust/Api"
          }
        }
      }
    ]
  })
}

# Read-only access to caller-owned buckets that hold external attachments. The
# attachment endpoint signs a download for any s3:// URL an authenticated org
# member supplies. Object reads only; the role has no list access.
resource "aws_iam_role_policy" "api_handler_external_attachment_read" {
  count = var.create_iam && length(var.external_attachment_s3_bucket_arns) > 0 ? 1 : 0

  name = "ExternalAttachmentRead"
  role = aws_iam_role.api_handler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "AllowReadExternalAttachmentObjects"
          Effect   = "Allow"
          Action   = ["s3:GetObject"]
          Resource = [for arn in var.external_attachment_s3_bucket_arns : "${arn}/*"]
        }
      ],
      length(var.external_attachment_s3_bucket_kms_key_arns) > 0 ? [
        {
          Sid      = "AllowKMSDecryptExternalAttachmentObjects"
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = var.external_attachment_s3_bucket_kms_key_arns
          Condition = {
            StringLike = {
              "kms:ViaService" = "s3.*.amazonaws.com"
            }
          }
        }
      ] : []
    )
  })
}

resource "aws_iam_policy" "api_handler" {
  count = var.create_iam ? 1 : 0

  name = "${var.deployment_name}-APIHandlerRolePolicy"
  # Keep the actions in step with local.customer_api_handler_policy in scopes.tf.
  policy = local.is_standalone_call ? local.customer_api_handler_policy : jsonencode({ # nosemgrep
    Statement = concat(
      [
        {
          Sid      = "AllowDescribeCacheClusters"
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
          Sid = "AllowReadWriteBuckets"
          Action = [
            "s3:AbortMultipartUpload",
            "s3:Get*",
            "s3:PutObject*",
            "s3:List*",
            "s3:DeleteObject*"
          ]
          Effect = "Allow"
          Resource = concat([
            var.created_resources.lambda_responses_s3_bucket_arn,
            "${var.created_resources.lambda_responses_s3_bucket_arn}/*",
            var.created_resources.code_bundle_s3_bucket_arn,
            "${var.created_resources.code_bundle_s3_bucket_arn}/*",
            ],
            local.brainstore_s3_bucket_arn != null && local.brainstore_s3_bucket_arn != "" ? [
              local.brainstore_s3_bucket_arn,
              "${local.brainstore_s3_bucket_arn}/*"
            ] : [],
            # Caller-provided attachment bucket. Grants both bucket-level
            # (List/GetBucket*) and object-level actions on the external bucket.
            var.existing_attachment_s3_bucket_arn != null && var.existing_attachment_s3_bucket_arn != "" ? [
              var.existing_attachment_s3_bucket_arn,
              "${var.existing_attachment_s3_bucket_arn}/*"
          ] : [])
        },
        {
          Sid    = "AllowUseKMSKeys"
          Effect = "Allow"
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ]
          Resource = var.existing_brainstore_s3_bucket_kms_key_arn != null ? [
            local.kms_key_arn,
            var.existing_brainstore_s3_bucket_kms_key_arn,
          ] : [local.kms_key_arn]
        },
        {
          Sid      = "AllowAssumeS3ExportRole"
          Action   = "sts:AssumeRole"
          Effect   = "Allow"
          Resource = length(var.s3_export_assume_role_arns) > 0 ? var.s3_export_assume_role_arns : ["*"]
          Condition = {
            StringLike = {
              "sts:ExternalId" = "bt:*"
            }
          }
        }
      ],
      local.create_ecs_api ? [
        {
          Sid    = "AllowECSExec"
          Effect = "Allow"
          Action = [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel",
          ]
          Resource = "*"
        }
      ] : [],
      # Grant KMS access to the caller-provided attachment bucket key only when
      # it is configured (i.e. the bucket uses SSE-KMS). Omitted otherwise.
      var.existing_attachment_s3_bucket_kms_key_arn != null && var.existing_attachment_s3_bucket_kms_key_arn != "" ? [
        {
          Sid    = "AllowUseAttachmentBucketKMSKey"
          Effect = "Allow"
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ]
          Resource = var.existing_attachment_s3_bucket_kms_key_arn
        }
      ] : []
    )
    Version = "2012-10-17"
  })

  tags = local.iam_tags
}
