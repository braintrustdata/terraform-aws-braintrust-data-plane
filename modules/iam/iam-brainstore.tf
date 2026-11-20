locals {
  # The Brainstore role also serves external EKS, which has no EC2 fleets and
  # takes its license and custom CA bundle from Helm. Those policy entries
  # exist only when Brainstore runs on EC2.
  brainstore_role_license_key_secret_arn   = local.create_brainstore_ec2 ? local.brainstore_license_key_secret_arn : null
  brainstore_role_license_key_kms_key_arn  = local.create_brainstore_ec2 ? local.brainstore_license_key_kms_key_arn : null
  brainstore_role_custom_ca_bundle_secret  = local.create_brainstore_ec2 ? var.custom_ca_bundle_secret_arn : null
  brainstore_role_custom_ca_bundle_kms_key = local.create_brainstore_ec2 ? var.custom_ca_bundle_kms_key_arn : null
}

resource "aws_iam_role" "brainstore" {
  count = var.create_iam ? 1 : 0

  # This is improperly named with "ec2" but changing it would cause a downtime for current customers
  name = local.role_names.brainstore
  path = local.role_paths.brainstore

  assume_role_policy = var.override_brainstore_iam_role_trust_policy != null ? var.override_brainstore_iam_role_trust_policy : jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = concat(
      # EC2 trust relationship
      [
        {
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
          Action = "sts:AssumeRole"
        }
      ],
      # IRSA trust relationship (cluster ARN is required)
      var.enable_eks_irsa && var.eks_cluster_arn != null ? [
        {
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
      ] : []
    )
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = merge({
    Name = local.role_names.brainstore
  }, local.iam_tags)

  lifecycle {
    # Some live stacks have older physical names.
    ignore_changes = [name]

    precondition {
      condition = !local.is_managed_call || alltrue([
        for arn in [
          local.kms_key_arn,
          var.created_resources.database_secret_arn,
          var.created_resources.function_tools_secret_arn,
          local.brainstore_s3_bucket_arn,
          var.created_resources.lambda_responses_s3_bucket_arn,
          var.created_resources.code_bundle_s3_bucket_arn,
        ] : arn != null
      ])
      error_message = "The Brainstore role needs the KMS key, database, function tools, Brainstore bucket, Lambda responses bucket and code bundle bucket ARNs. Pass them in created_resources, kms_key_arn or existing_brainstore_s3_bucket_arn."
    }
  }
}

resource "aws_iam_role_policy" "brainstore_s3_access" {
  count = var.create_iam ? 1 : 0

  name = "brainstore-s3-bucket"
  role = aws_iam_role.brainstore[0].id

  # Keep the actions in step with local.customer_brainstore_s3_access_policy in scopes.tf.

  policy = local.is_standalone_call ? local.customer_brainstore_s3_access_policy : jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:Get*",
          "s3:PutObject*",
          "s3:List*",
          "s3:DeleteObject*"
        ]
        Resource = [
          local.brainstore_s3_bucket_arn,
          "${local.brainstore_s3_bucket_arn}/*",
          var.created_resources.lambda_responses_s3_bucket_arn,
          "${var.created_resources.lambda_responses_s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.created_resources.code_bundle_s3_bucket_arn,
          "${var.created_resources.code_bundle_s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_secrets_access" {
  count = var.create_iam ? 1 : 0

  name = "secrets-access"
  role = aws_iam_role.brainstore[0].id

  # Keep the actions in step with local.customer_brainstore_secrets_access_policy in scopes.tf.

  policy = local.is_standalone_call ? local.customer_brainstore_secrets_access_policy : jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = "secretsmanager:GetSecretValue"
          Resource = compact(concat(
            [
              var.created_resources.database_secret_arn,
              var.created_resources.function_tools_secret_arn,
              local.brainstore_role_license_key_secret_arn,
              var.created_resources.internal_observability_api_key_secret_arn,
            ],
            local.brainstore_role_custom_ca_bundle_secret == null ? [] : [local.brainstore_role_custom_ca_bundle_secret],
          ))
        }
      ],
      local.brainstore_role_license_key_kms_key_arn == null ? [] : [{
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = local.brainstore_role_license_key_kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }],
      local.brainstore_role_custom_ca_bundle_kms_key == null ? [] : [
        {
          Effect   = "Allow"
          Action   = "kms:Decrypt"
          Resource = local.brainstore_role_custom_ca_bundle_kms_key
          Condition = {
            StringEquals = {
              "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
            }
          }
        }
      ]
    )
  })
}

resource "aws_iam_role_policy" "brainstore_export_assume_role" {
  count = var.create_iam && var.brainstore_enable_export ? 1 : 0

  name = "export-assume-role"
  role = aws_iam_role.brainstore[0].id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Resource = length(var.s3_export_assume_role_arns) > 0 ? var.s3_export_assume_role_arns : ["*"]
        Condition = {
          StringLike = {
            "sts:ExternalId" = "bt:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_cloudwatch_metrics" {
  count = var.create_iam ? 1 : 0

  name = "cloudwatch-agent-metrics"
  role = aws_iam_role.brainstore[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : ["cloudwatch:PutMetricData"],
        Resource : "*",
        Condition : {
          StringEquals : { "cloudwatch:namespace" : "CWAgent" }
        }
      },
      {
        Effect : "Allow",
        Action : ["ec2:DescribeTags"],
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_cloudwatch_logs_access" {
  count = var.create_iam ? 1 : 0

  name = "cloudwatch-logs-access"
  role = aws_iam_role.brainstore[0].id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/brainstore:*",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/brainstore/*:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "brainstore_ssm" {
  count = var.create_iam && var.enable_brainstore_ec2_ssm ? 1 : 0

  role       = aws_iam_role.brainstore[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "brainstore_additional_policy" {
  count = var.create_iam ? length(var.brainstore_additional_policy_arns) : 0

  role       = aws_iam_role.brainstore[0].name
  policy_arn = var.brainstore_additional_policy_arns[count.index]
}

resource "aws_iam_role_policy" "brainstore_kms_policy" {
  count = var.create_iam ? 1 : 0

  name = "${var.deployment_name}-brainstore-kms-policy"
  role = aws_iam_role.brainstore[0].id

  # Keep the actions in step with local.customer_brainstore_kms_policy in scopes.tf.

  policy = local.is_standalone_call ? local.customer_brainstore_kms_policy : jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
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
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_ssm_parameter_access" {
  count = var.create_iam ? 1 : 0

  name = "brainstore-ssm-parameter-access"
  role = aws_iam_role.brainstore[0].id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ssm:GetParameter"
        Resource = concat(
          [
            "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/braintrust/${var.deployment_name}/ai-proxy-url",
          ],
          local.create_ecs_api ? [
            "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/braintrust/${var.deployment_name}/ecs-api-url",
          ] : []
        )
      }
    ]
  })
}

# The Brainstore instance profile and the Redis secret policy exist only when
# Brainstore runs on EC2.
resource "aws_iam_instance_profile" "brainstore" {
  count = var.create_iam && local.create_brainstore_ec2 ? 1 : 0

  name = local.instance_profile_names.brainstore
  path = local.instance_profile_paths.brainstore
  role = aws_iam_role.brainstore[0].name

  tags = local.iam_tags_deployment_name_wins
}

resource "aws_iam_role_policy" "brainstore_redis_secret_access" {
  count = var.create_iam && local.create_brainstore_ec2 ? 1 : 0

  name = "redis-secret-access"
  role = aws_iam_role.brainstore[0].name

  # Keep the actions in step with local.customer_brainstore_redis_secret_access_policy in scopes.tf.

  policy = local.is_standalone_call ? local.customer_brainstore_redis_secret_access_policy : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.created_resources.redis_url_secret_arn
      }
    ]
  })

  lifecycle {
    precondition {
      condition     = !local.is_managed_call || var.created_resources.redis_url_secret_arn != null
      error_message = "The Brainstore Redis secret policy needs redis_url_secret_arn in created_resources."
    }
  }
}
