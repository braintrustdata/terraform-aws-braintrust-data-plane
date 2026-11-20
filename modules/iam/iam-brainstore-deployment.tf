resource "aws_iam_role" "brainstore_deployment_waiter" {
  count = var.create_iam && local.create_brainstore_deployment_waiter ? 1 : 0

  name                 = local.role_names.brainstore_deployment_waiter
  path                 = local.role_paths.brainstore_deployment_waiter
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.iam_tags_deployment_name_wins

  lifecycle {
    precondition {
      condition     = !local.is_managed_call || (var.brainstore_deployment_log_group_arn != null && length(var.brainstore_asg_names) > 0)
      error_message = "The Brainstore deployment waiter role needs brainstore_deployment_log_group_arn and at least one name in brainstore_asg_names. IAM rejects a policy with an empty Resource list."
    }
  }
}

# The policy name stays unset. Existing stacks have a provider-generated name,
# and setting one would replace it.
resource "aws_iam_role_policy" "brainstore_deployment_waiter" {
  count = var.create_iam && local.create_brainstore_deployment_waiter ? 1 : 0

  role = aws_iam_role.brainstore_deployment_waiter[0].id
  # Keep the actions in step with local.customer_brainstore_deployment_waiter_policy in scopes.tf.
  policy = local.is_standalone_call ? local.customer_brainstore_deployment_waiter_policy : jsonencode({
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
        Resource = [for asg_name in var.brainstore_asg_names : "arn:${local.partition}:autoscaling:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${asg_name}"]
        Condition = {
          StringEquals = { "autoscaling:ResourceTag/BraintrustDeploymentName" = var.deployment_name }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${var.brainstore_deployment_log_group_arn}:*"
      },
    ]
  })
}
