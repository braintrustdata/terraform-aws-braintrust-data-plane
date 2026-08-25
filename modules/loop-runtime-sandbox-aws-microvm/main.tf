data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  region    = data.aws_region.current.region
  partition = data.aws_partition.current.partition

  artifact_bucket_name = coalesce(var.artifact_bucket_name, "braintrust-assets-${local.region}")

  # MicroVM image name; must be unique per deployment.
  image_name = "bt-loop-${var.deployment_name}"

  base_image_arn = "arn:${local.partition}:lambda:${local.region}:aws:microvm-image:al2023-1"

  # AWS-managed network connectors used at RunMicrovm time.
  managed_ingress_connector_arn = "arn:${local.partition}:lambda:${local.region}:aws:network-connector:aws-network-connector:ALL_INGRESS"
  managed_egress_connector_arn  = "arn:${local.partition}:lambda:${local.region}:aws:network-connector:aws-network-connector:INTERNET_EGRESS"
  ingress_connector_arns        = length(var.ingress_network_connector_arns) > 0 ? var.ingress_network_connector_arns : [local.managed_ingress_connector_arn]

  # Match CloudFormation's fail-closed behavior: only the exact value
  # "internet" permits public Internet egress from sandbox MicroVMs.
  use_restricted_egress = var.sandbox_egress_mode != "internet"
  egress_connector_arns = local.use_restricted_egress ? [
    aws_cloudformation_stack.restricted_egress_connector[0].outputs["NetworkConnectorArn"]
  ] : [local.managed_egress_connector_arn]

  # Resolve the content-addressed artifact key from the published version pointer
  # (same convention as modules/services lambda zips).
  artifact_key      = trimspace(data.http.microvm_artifact_version.response_body)
  code_artifact_uri = "s3://${local.artifact_bucket_name}/${local.artifact_key}"

  image_arn = aws_cloudformation_stack.microvm_image.outputs["ImageArn"]

  # IAM statements the Loop runtime ECS *task* role needs to drive MicroVMs.
  # Emitted as an output so the compute module can attach it without knowing
  # anything MicroVM-specific.
  task_role_policy = {
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "LoopRuntimeMicrovmLifecycle"
        Effect = "Allow"
        Action = [
          "lambda:RunMicrovm",
          "lambda:GetMicrovm",
          "lambda:ResumeMicrovm",
          "lambda:SuspendMicrovm",
          "lambda:CreateMicrovmAuthToken",
          "lambda:TerminateMicrovm",
        ]
        Resource = local.image_arn
      },
      {
        Sid      = "LoopRuntimeMicrovmNetworkConnectors"
        Effect   = "Allow"
        Action   = ["lambda:PassNetworkConnector"]
        Resource = distinct(concat(local.ingress_connector_arns, local.egress_connector_arns))
      },
      ], var.enable_microvm_runtime_logs ? [
      {
        Sid      = "LoopRuntimeMicrovmPassExecutionRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.microvm_execution[0].arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      }
    ] : [])
  }

  # Environment variables the compute module merges into the container. Nothing
  # else in the compute module references MicroVMs.
  sandbox_env_vars = merge({
    EXO_SANDBOX_PROVIDER                              = "aws-lambda-microvm"
    EXO_SANDBOX_IMAGE                                 = "lambda-microvm"
    AWS_LAMBDA_MICROVM_IMAGE_IDENTIFIER               = local.image_arn
    AWS_LAMBDA_MICROVM_REGION                         = local.region
    AWS_LAMBDA_MICROVM_INGRESS_NETWORK_CONNECTOR_ARNS = join(",", local.ingress_connector_arns)
    AWS_LAMBDA_MICROVM_EGRESS_NETWORK_CONNECTOR_ARNS  = join(",", local.egress_connector_arns)
    AWS_LAMBDA_MICROVM_MAX_IDLE_DURATION_SECONDS      = tostring(var.microvm_max_idle_duration_seconds)
    AWS_LAMBDA_MICROVM_SUSPENDED_DURATION_SECONDS     = tostring(var.microvm_suspended_duration_seconds)
    AWS_LAMBDA_MICROVM_AUTO_RESUME_ENABLED            = "true"
    AWS_LAMBDA_MICROVM_MAXIMUM_DURATION_SECONDS       = tostring(var.microvm_maximum_duration_seconds)
    AWS_LAMBDA_MICROVM_AUTH_TOKEN_EXPIRATION_MINUTES  = tostring(var.microvm_auth_token_expiration_minutes)
    AWS_LAMBDA_MICROVM_RUNTIME_PORT                   = tostring(var.microvm_runtime_port)
    },
    var.enable_microvm_runtime_logs ? {
      AWS_LAMBDA_MICROVM_EXECUTION_ROLE_ARN   = aws_iam_role.microvm_execution[0].arn
      AWS_LAMBDA_MICROVM_ALLOW_EXECUTION_ROLE = "true"
    } : {}
  )
}

# Resolve the published MicroVM guest-zip version pointer (body is the key).
data "http" "microvm_artifact_version" {
  url = "https://${local.artifact_bucket_name}.s3.${local.region}.amazonaws.com/${var.artifact_key_prefix}/version-${var.microvm_version_tag}"

  retry {
    attempts     = 5
    min_delay_ms = 500
    max_delay_ms = 5000
  }
  request_timeout_ms = 10000

  lifecycle {
    postcondition {
      condition     = self.status_code < 400
      error_message = "Failed to resolve MicroVM artifact version pointer at ${self.url} (status ${self.status_code})."
    }
  }
}

# Single log group used for image build logs and (opt-in) MicroVM runtime logs.
resource "aws_cloudwatch_log_group" "microvm_image" {
  name              = "/aws/lambda/microvms/${local.image_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-microvm"
  }, local.common_tags)
}

data "aws_iam_policy_document" "microvm_build_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "network_connector_operator_assume_role" {
  count = local.use_restricted_egress ? 1 : 0

  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_vpc" "restricted_egress" {
  count = local.use_restricted_egress ? 1 : 0

  cidr_block           = "10.255.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-restricted-egress"
  }, local.common_tags)

  lifecycle {
    precondition {
      condition     = length(var.availability_zone_names) == 3
      error_message = "Restricted Loop egress requires 3 availability_zone_names matching the gateway ALB / main private subnets."
    }
  }
}

resource "aws_route_table" "restricted_egress" {
  count = local.use_restricted_egress ? 1 : 0

  vpc_id = aws_vpc.restricted_egress[0].id

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-restricted-egress"
  }, local.common_tags)
}

resource "aws_subnet" "restricted_egress" {
  count = local.use_restricted_egress ? 3 : 0

  availability_zone       = var.availability_zone_names[count.index]
  cidr_block              = "10.255.${count.index + 1}.0/24"
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.restricted_egress[0].id

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-restricted-egress-subnet-${count.index + 1}"
  }, local.common_tags)
}

resource "aws_route_table_association" "restricted_egress" {
  count = local.use_restricted_egress ? 3 : 0

  route_table_id = aws_route_table.restricted_egress[0].id
  subnet_id      = aws_subnet.restricted_egress[count.index].id
}

resource "aws_route53_resolver_firewall_domain_list" "restricted_egress" {
  count = local.use_restricted_egress ? 1 : 0

  domains = ["*"]
  name    = "bt-loop-${var.deployment_name}-dns-domains"
  tags    = local.common_tags
}

resource "aws_route53_resolver_firewall_rule_group" "restricted_egress" {
  count = local.use_restricted_egress ? 1 : 0

  name = "bt-loop-${var.deployment_name}-dns-rules"
  tags = local.common_tags
}

resource "aws_route53_resolver_firewall_rule" "restricted_egress" {
  count = local.use_restricted_egress ? 1 : 0

  action                  = "BLOCK"
  block_response          = "NXDOMAIN"
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.restricted_egress[0].id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.restricted_egress[0].id
  name                    = "bt-loop-${var.deployment_name}-dns-block-all"
  priority                = 100
}

resource "aws_route53_resolver_firewall_domain_list" "restricted_egress_privatelink" {
  count = local.use_restricted_egress && var.create_privatelink_endpoint ? 1 : 0

  domains = ["*.vpce.amazonaws.com"]
  name    = "bt-loop-${var.deployment_name}-dns-allow-vpce"
  tags    = local.common_tags
}

resource "aws_route53_resolver_firewall_rule" "restricted_egress_privatelink_allow" {
  count = local.use_restricted_egress && var.create_privatelink_endpoint ? 1 : 0

  action                  = "ALLOW"
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.restricted_egress_privatelink[0].id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.restricted_egress[0].id
  name                    = "bt-loop-${var.deployment_name}-dns-allow-vpce"
  priority                = 50
}

resource "aws_route53_resolver_firewall_rule_group_association" "restricted_egress" {
  count = local.use_restricted_egress ? 1 : 0

  depends_on = [
    aws_route53_resolver_firewall_rule.restricted_egress,
    aws_route53_resolver_firewall_rule.restricted_egress_privatelink_allow,
  ]

  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.restricted_egress[0].id
  name                   = "bt-loop-${var.deployment_name}-dns-assoc"
  priority               = 101
  vpc_id                 = aws_vpc.restricted_egress[0].id
  tags                   = local.common_tags
}

resource "aws_security_group" "restricted_egress" {
  count = local.use_restricted_egress ? 1 : 0

  description = "Security group for restricted Loop runtime sandbox egress"
  name        = "${var.deployment_name}-loop-runtime-restricted-egress"
  vpc_id      = aws_vpc.restricted_egress[0].id

  egress = var.create_privatelink_endpoint ? [
    {
      description      = "Allow HTTP to the private gateway VPC endpoint"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      security_groups  = [aws_security_group.loop_gateway_privatelink_endpoint[0].id]
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      self             = false
    }
  ] : []

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-restricted-egress"
  }, local.common_tags)
}

resource "aws_security_group" "loop_gateway_privatelink_endpoint" {
  count = local.use_restricted_egress && var.create_privatelink_endpoint ? 1 : 0

  name        = "${var.deployment_name}-loop-gw-pl-vpce"
  description = "Security group for Loop VPC endpoint to private gateway"
  vpc_id      = aws_vpc.restricted_egress[0].id

  tags = merge({
    Name = "${var.deployment_name}-loop-gw-pl-vpce"
  }, local.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "loop_gateway_privatelink_endpoint_http" {
  count = local.use_restricted_egress && var.create_privatelink_endpoint ? 1 : 0

  security_group_id            = aws_security_group.loop_gateway_privatelink_endpoint[0].id
  referenced_security_group_id = aws_security_group.restricted_egress[0].id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP from restricted Loop MicroVMs to the private gateway VPC endpoint."

  tags = merge({
    Name = "${var.deployment_name}-loop-gw-pl-vpce-http"
  }, local.common_tags)
}

resource "aws_vpc_security_group_egress_rule" "loop_gateway_privatelink_endpoint_all" {
  count = local.use_restricted_egress && var.create_privatelink_endpoint ? 1 : 0

  security_group_id = aws_security_group.loop_gateway_privatelink_endpoint[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from the Loop gateway VPC endpoint."

  tags = merge({
    Name = "${var.deployment_name}-loop-gw-pl-vpce-egress"
  }, local.common_tags)
}

resource "aws_iam_role" "network_connector_operator" {
  count = local.use_restricted_egress ? 1 : 0

  name                 = "${var.deployment_name}-loop-runtime-network-connector"
  assume_role_policy   = data.aws_iam_policy_document.network_connector_operator_assume_role[0].json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-network-connector"
  }, local.common_tags)
}

resource "aws_iam_role_policy_attachment" "network_connector_operator" {
  count = local.use_restricted_egress ? 1 : 0

  role       = aws_iam_role.network_connector_operator[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSLambdaNetworkConnectorOperatorPolicy"
}

# AWS provider v6 does not expose AWS::Lambda::NetworkConnector. Keep this
# isolated CloudFormation stack alongside the existing MicroVM image stack,
# while Terraform manages the surrounding network and IAM resources.
resource "aws_cloudformation_stack" "restricted_egress_connector" {
  count = local.use_restricted_egress ? 1 : 0

  name = "${var.deployment_name}-loop-runtime-restricted-egress-connector"

  depends_on = [
    aws_iam_role_policy_attachment.network_connector_operator,
    aws_route53_resolver_firewall_rule_group_association.restricted_egress,
  ]

  parameters = {
    ConnectorName   = "bt-loop-${var.deployment_name}-restricted-egress"
    OperatorRoleArn = aws_iam_role.network_connector_operator[0].arn
    SecurityGroupId = aws_security_group.restricted_egress[0].id
    SubnetIds       = join(",", aws_subnet.restricted_egress[*].id)
  }

  template_body = <<-YAML
    AWSTemplateFormatVersion: "2010-09-09"
    Parameters:
      ConnectorName:
        Type: String
      OperatorRoleArn:
        Type: String
      SecurityGroupId:
        Type: String
      SubnetIds:
        Type: CommaDelimitedList
    Resources:
      RestrictedEgressConnector:
        Type: AWS::Lambda::NetworkConnector
        Properties:
          Name: !Ref ConnectorName
          OperatorRole: !Ref OperatorRoleArn
          Configuration:
            VpcEgressConfiguration:
              AssociatedComputeResourceTypes:
                - MicroVm
              NetworkProtocol: IPv4
              SecurityGroupIds:
                - !Ref SecurityGroupId
              SubnetIds: !Ref SubnetIds
    Outputs:
      NetworkConnectorArn:
        Value: !GetAtt RestrictedEgressConnector.Arn
  YAML

  tags = local.common_tags
}

resource "aws_iam_role" "microvm_image_build" {
  name                 = "${var.deployment_name}-loop-runtime-microvm-build"
  assume_role_policy   = data.aws_iam_policy_document.microvm_build_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-microvm-build"
  }, local.common_tags)
}

data "aws_iam_policy_document" "microvm_image_build" {
  statement {
    sid       = "ReadMicrovmArtifact"
    actions   = ["s3:GetObject"]
    resources = ["arn:${local.partition}:s3:::${local.artifact_bucket_name}/*"]
  }
  statement {
    sid = "MicrovmBuildLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "microvm_image_build" {
  name   = "${var.deployment_name}-loop-runtime-microvm-build"
  role   = aws_iam_role.microvm_image_build.id
  policy = data.aws_iam_policy_document.microvm_image_build.json
}

# Opt-in execution role for exporting MicroVM stdout/stderr to CloudWatch.
data "aws_iam_policy_document" "microvm_execution_assume_role" {
  count = var.enable_microvm_runtime_logs ? 1 : 0
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "microvm_execution" {
  count                = var.enable_microvm_runtime_logs ? 1 : 0
  name                 = "${var.deployment_name}-loop-runtime-microvm-exec"
  assume_role_policy   = data.aws_iam_policy_document.microvm_execution_assume_role[0].json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-microvm-exec"
  }, local.common_tags)
}

resource "aws_iam_role_policy" "microvm_execution" {
  count = var.enable_microvm_runtime_logs ? 1 : 0
  name  = "${var.deployment_name}-loop-runtime-microvm-exec"
  role  = aws_iam_role.microvm_execution[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup"]
        Resource = "arn:${local.partition}:logs:${local.region}:*:log-group:${aws_cloudwatch_log_group.microvm_image.name}"
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        # Stream actions operate on log-stream ARNs beneath the group. TF's
        # log-group .arn has no ":*" suffix (unlike CFN's GetAtt), so append it.
        Resource = "${aws_cloudwatch_log_group.microvm_image.arn}:*"
      }
    ]
  })
}

# MicroVM image built via a scoped nested CloudFormation stack. The AWS provider
# has no native AWS::Lambda::MicrovmImage resource, and the awscc provider cannot
# create it (Cloud Control prunes the empty-but-required EgressNetworkConnectors/
# EnvironmentVariables/Hooks keys -> 400). CloudFormation accepts them, matching
# the BYOC template semantics.
resource "aws_cloudformation_stack" "microvm_image" {
  name = "${var.deployment_name}-loop-runtime-microvm-image"

  # The image build assumes microvm_image_build to fetch the artifact and write
  # logs; without this the stack can start before the role's inline policy is
  # attached, so the build assumes an unprivileged role and fails on first apply.
  depends_on = [aws_iam_role_policy.microvm_image_build]

  template_body = <<-YAML
    AWSTemplateFormatVersion: "2010-09-09"
    Resources:
      MicrovmImage:
        Type: AWS::Lambda::MicrovmImage
        UpdateReplacePolicy: Retain
        Properties:
          Name: ${local.image_name}
          BaseImageArn: ${local.base_image_arn}
          BaseImageVersion: "0"
          BuildRoleArn: ${aws_iam_role.microvm_image_build.arn}
          Description: "Braintrust Loop runtime sandbox MicroVM image for ${var.deployment_name}."
          CodeArtifact:
            Uri: ${local.code_artifact_uri}
          CpuConfigurations:
            - Architecture: ARM_64
          Resources:
            - MinimumMemoryInMiB: ${var.microvm_minimum_memory_mib}
          AdditionalOsCapabilities:
            - ALL
          EgressNetworkConnectors: []
          EnvironmentVariables: []
          Hooks:
            MicrovmHooks: {}
            MicrovmImageHooks: {}
          Logging:
            CloudWatch:
              LogGroup: ${aws_cloudwatch_log_group.microvm_image.name}
          Tags:
            - Key: BraintrustLoopRuntime
              Value: "true"
    Outputs:
      ImageArn:
        Value: !GetAtt MicrovmImage.ImageArn
  YAML

  tags = local.common_tags

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}
