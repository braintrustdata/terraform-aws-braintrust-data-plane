data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "task_exec_ssm_messages" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.deployment_name}-api-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-task-exec"
  }, local.common_tags)
}

resource "aws_iam_role_policy_attachment" "task_execution_default" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.deployment_name}-api-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-task"
  }, local.common_tags)
}

resource "aws_iam_role_policy" "task_exec_ssm_messages" {
  name   = "${var.deployment_name}-api-ecs-task-exec-ssm-messages"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_exec_ssm_messages.json
}

resource "aws_iam_role_policy" "task_exec_kms" {
  name = "${var.deployment_name}-api-ecs-task-exec-kms"
  role = aws_iam_role.task.id

  policy = jsonencode({
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
        Resource = var.kms_key_arn
      }
    ]
  })
}
