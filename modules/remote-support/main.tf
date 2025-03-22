locals {
  has_braintrust_support_access = var.enable_braintrust_support_logs_access || var.enable_braintrust_support_shell_access
}

# Role that can be assumed by Braintrust support team to optionally access Cloudwatch logs or optionally access the bastion host
resource "aws_iam_role" "braintrust_support" {
  count = local.has_braintrust_support_access ? 1 : 0

  name = "${var.deployment_name}-braintrust-support"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::872608195481:root" # Braintrust's AWS account
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "braintrust_support_logs" {
  count = var.enable_braintrust_support_logs_access ? 1 : 0

  name = "braintrust-support-logs-access"
  role = aws_iam_role.braintrust_support[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartLiveTail",
          "logs:StopLiveTail"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}*:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.deployment_name}*:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.deployment_name}*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        # This is unavoidable. AWS does not allow restricting Describe calls.
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "bastion_ssh" {
  count = var.enable_braintrust_support_shell_access ? 1 : 0

  name        = "${var.deployment_name}-bastion-ssh"
  description = "Security group for SSH access to Braintrust bastion host"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.instance_connect_endpoint[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_connect_endpoint" {
  count = var.enable_braintrust_support_shell_access ? 1 : 0

  name        = "${var.deployment_name}-instance-connect-endpoint"
  description = "Security group for EC2 Instance Connect Endpoint"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ec2_instance_connect_endpoint" "bastion" {
  count = var.enable_braintrust_support_shell_access ? 1 : 0

  subnet_id          = var.public_subnet_ids[0]
  security_group_ids = [aws_security_group.instance_connect_endpoint[0].id]
  preserve_client_ip = true

  tags = {
    Name = "${var.deployment_name}-instance-connect-endpoint"
  }
}

resource "aws_iam_role" "bastion" {
  count = var.enable_braintrust_support_shell_access ? 1 : 0

  name = "${var.deployment_name}-bastion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  count = var.enable_braintrust_support_shell_access ? 1 : 0

  name = "${var.deployment_name}-bastion"
  role = aws_iam_role.bastion[0].name
}

resource "aws_iam_role_policy" "bastion" {
  count = var.enable_braintrust_support_shell_access ? 1 : 0

  name = "bastion-permissions"
  role = aws_iam_role.bastion[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceConnectEndpoints",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        # This is unavoidable. AWS does not allow restricting Describe calls
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustDeploymentName" = var.deployment_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeFunctionUrl",
          "lambda:InvokeAsync",
          "lambda:GetFunction*"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustDeploymentName" = var.deployment_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = compact([
          var.database_secret_arn,
          var.clickhouse_secret_arn
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "braintrust_support_ec2_connect" {
  count = var.enable_braintrust_support_shell_access ? 1 : 0

  name = "ec2-instance-connect-bastion"
  role = aws_iam_role.braintrust_support[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceConnectEndpoints"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2-instance-connect:SendSSHPublicKey",
          "ec2-instance-connect:OpenTunnel"
        ]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.bastion[0].id}",
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance-connect-endpoint/${aws_ec2_instance_connect_endpoint.bastion[0].id}"
        ]
      }
    ]
  })
}

resource "aws_instance" "bastion" {
  count = var.enable_braintrust_support_shell_access ? 1 : 0

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t4g.medium"

  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion_ssh[0].id]
  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.bastion[0].name

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(templatefile("${path.module}/bastion-user-data.sh", {
    deployment_name       = var.deployment_name
    region                = data.aws_region.current.name
    database_host         = var.database_host
    database_secret_arn   = var.database_secret_arn
    clickhouse_host       = var.clickhouse_host != null ? var.clickhouse_host : ""
    clickhouse_secret_arn = var.clickhouse_secret_arn != null ? var.clickhouse_secret_arn : ""
    redis_host            = var.redis_host
    redis_port            = var.redis_port
    lambda_function_arns  = var.lambda_function_arns
  }))

  tags = {
    Name = "${var.deployment_name}-bastion"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

