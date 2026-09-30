data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

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

  # AWS-managed ingress connector used at RunMicrovm time. Sandboxes never get
  # the AWS-managed Internet egress connector; their only egress is the
  # restricted VPC connector, which reaches just the Loop egress gateway.
  managed_ingress_connector_arn = "arn:${local.partition}:lambda:${local.region}:aws:network-connector:aws-network-connector:ALL_INGRESS"
  ingress_connector_arns        = length(var.ingress_network_connector_arns) > 0 ? var.ingress_network_connector_arns : [local.managed_ingress_connector_arn]

  create_restricted_egress_vpc = var.existing_vpc_id == null
  restricted_egress_vpc_id     = var.existing_vpc_id != null ? var.existing_vpc_id : one(aws_vpc.restricted_egress[*].id)
  existing_private_subnet_ids = [
    var.existing_private_subnet_1_id,
    var.existing_private_subnet_2_id,
    var.existing_private_subnet_3_id,
  ]
  restricted_egress_subnet_ids = var.existing_vpc_id != null ? local.existing_private_subnet_ids : aws_subnet.restricted_egress[*].id
  sandbox_subnet_azs           = var.existing_vpc_id != null ? data.aws_subnet.restricted_egress_existing[*].availability_zone : aws_subnet.restricted_egress[*].availability_zone
  egress_gateway_nlb_azs       = data.aws_subnet.egress_gateway_nlb[*].availability_zone
  main_endpoint_subnet_ids = [
    for az in distinct(local.egress_gateway_nlb_azs) : var.endpoint_subnet_ids[index(local.egress_gateway_nlb_azs, az)]
  ]
  egress_gateway_subnet_ids = [
    for az in distinct(local.sandbox_subnet_azs) : local.restricted_egress_subnet_ids[index(local.sandbox_subnet_azs, az)]
    if contains(local.egress_gateway_nlb_azs, az)
  ]
  egress_connector_arns = [
    aws_cloudformation_stack.restricted_egress_connector.outputs["NetworkConnectorArn"]
  ]

  # The Loop runtime serves the sandbox egress proxy on this port. Sandboxes
  # reach it through a PrivateLink endpoint in the sandbox VPC.
  egress_gateway_port     = 4002
  egress_gateway_dns_name = aws_vpc_endpoint.egress_gateway.dns_entry[0].dns_name

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
    AWS_LAMBDA_MICROVM_IMAGE_VERSION                  = aws_cloudformation_stack.microvm_image.outputs["ImageVersion"]
    AWS_LAMBDA_MICROVM_REGION                         = local.region
    AWS_LAMBDA_MICROVM_INGRESS_NETWORK_CONNECTOR_ARNS = join(",", local.ingress_connector_arns)
    AWS_LAMBDA_MICROVM_EGRESS_NETWORK_CONNECTOR_ARNS  = join(",", local.egress_connector_arns)
    AWS_LAMBDA_MICROVM_MAX_IDLE_DURATION_SECONDS      = tostring(var.microvm_max_idle_duration_seconds)
    AWS_LAMBDA_MICROVM_SUSPENDED_DURATION_SECONDS     = tostring(var.microvm_suspended_duration_seconds)
    AWS_LAMBDA_MICROVM_AUTO_RESUME_ENABLED            = "true"
    AWS_LAMBDA_MICROVM_MAXIMUM_DURATION_SECONDS       = tostring(var.microvm_maximum_duration_seconds)
    AWS_LAMBDA_MICROVM_AUTH_TOKEN_EXPIRATION_MINUTES  = tostring(var.microvm_auth_token_expiration_minutes)
    AWS_LAMBDA_MICROVM_RUNTIME_PORT                   = tostring(var.microvm_runtime_port)
    LOOP_RUNTIME_SANDBOX_FORWARD_PROXY_LISTEN         = "0.0.0.0:${local.egress_gateway_port}"
    LOOP_RUNTIME_SANDBOX_EGRESS_GATEWAY_URL           = "http://${local.egress_gateway_dns_name}:${local.egress_gateway_port}"
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
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_vpc" "restricted_egress" {
  count = local.create_restricted_egress_vpc ? 1 : 0

  cidr_block           = "10.255.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-restricted-egress"
  }, local.common_tags)
}

resource "aws_route_table" "restricted_egress" {
  count = local.create_restricted_egress_vpc ? 1 : 0

  vpc_id = aws_vpc.restricted_egress[0].id

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-restricted-egress"
  }, local.common_tags)
}

resource "aws_subnet" "restricted_egress" {
  count = local.create_restricted_egress_vpc ? 3 : 0

  availability_zone       = element(local.egress_gateway_nlb_azs, count.index)
  cidr_block              = "10.255.${count.index + 1}.0/24"
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.restricted_egress[0].id

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-restricted-egress-subnet-${count.index + 1}"
  }, local.common_tags)
}

resource "aws_route_table_association" "restricted_egress" {
  count = local.create_restricted_egress_vpc ? 3 : 0

  route_table_id = aws_route_table.restricted_egress[0].id
  subnet_id      = aws_subnet.restricted_egress[count.index].id
}

resource "aws_route53_resolver_firewall_domain_list" "restricted_egress" {
  count = local.create_restricted_egress_vpc ? 1 : 0

  domains = ["*."]
  name    = "bt-loop-${var.deployment_name}-dns-domains"
  tags    = local.common_tags
}

resource "aws_route53_resolver_firewall_rule_group" "restricted_egress" {
  count = local.create_restricted_egress_vpc ? 1 : 0

  name = "bt-loop-${var.deployment_name}-dns-rules"
  tags = local.common_tags
}

resource "aws_route53_resolver_firewall_rule" "restricted_egress" {
  count = local.create_restricted_egress_vpc ? 1 : 0

  action                  = "BLOCK"
  block_response          = "NXDOMAIN"
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.restricted_egress[0].id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.restricted_egress[0].id
  name                    = "bt-loop-${var.deployment_name}-dns-block-all"
  priority                = 100
}

# Sandboxes resolve only the egress gateway endpoint. AWS stores firewall
# domains with a trailing dot, so write it that way to avoid plan drift.
resource "aws_route53_resolver_firewall_domain_list" "egress_gateway" {
  count = local.create_restricted_egress_vpc ? 1 : 0

  domains = ["${local.egress_gateway_dns_name}."]
  name    = "bt-loop-${var.deployment_name}-egress-gateway-dns"
  tags    = local.common_tags
}

resource "aws_route53_resolver_firewall_rule" "egress_gateway_allow" {
  count = local.create_restricted_egress_vpc ? 1 : 0

  action                  = "ALLOW"
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.egress_gateway[0].id
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.restricted_egress[0].id
  name                    = "bt-loop-${var.deployment_name}-dns-allow-egress-gateway"
  priority                = 50
}

resource "aws_route53_resolver_firewall_rule_group_association" "restricted_egress" {
  count = local.create_restricted_egress_vpc ? 1 : 0

  depends_on = [
    aws_route53_resolver_firewall_rule.egress_gateway_allow,
    aws_route53_resolver_firewall_rule.restricted_egress,
  ]

  firewall_rule_group_id = aws_route53_resolver_firewall_rule_group.restricted_egress[0].id
  name                   = "bt-loop-${var.deployment_name}-dns-assoc"
  priority               = 101
  vpc_id                 = aws_vpc.restricted_egress[0].id
  tags                   = local.common_tags
}

# Outbound access is limited to aws_vpc_security_group_egress_rule
# .sandbox_to_egress_gateway. Terraform removes the default allow-all rule.
resource "aws_security_group" "restricted_egress" {
  description = "Security group for restricted Loop runtime sandbox egress"
  name        = "${var.deployment_name}-loop-runtime-restricted-egress"
  vpc_id      = local.restricted_egress_vpc_id

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-restricted-egress"
  }, local.common_tags)
}

resource "aws_iam_role" "network_connector_operator" {
  name                 = "${var.deployment_name}-loop-runtime-network-connector"
  assume_role_policy   = data.aws_iam_policy_document.network_connector_operator_assume_role.json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-network-connector"
  }, local.common_tags)
}

resource "aws_iam_role_policy_attachment" "network_connector_operator" {
  role       = aws_iam_role.network_connector_operator.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AWSLambdaNetworkConnectorOperatorPolicy"
}

# AWS provider v6 does not expose AWS::Lambda::NetworkConnector. Keep this
# isolated CloudFormation stack alongside the existing MicroVM image stack,
# while Terraform manages the surrounding network and IAM resources.
resource "aws_cloudformation_stack" "restricted_egress_connector" {
  name = "${var.deployment_name}-loop-runtime-restricted-egress-connector"

  depends_on = [
    aws_iam_role_policy_attachment.network_connector_operator,
    data.aws_subnet.restricted_egress_existing,
    aws_route53_resolver_firewall_rule_group_association.restricted_egress,
  ]

  parameters = {
    ConnectorName   = "bt-loop-${var.deployment_name}-restricted-egress"
    OperatorRoleArn = aws_iam_role.network_connector_operator.arn
    SecurityGroupId = aws_security_group.restricted_egress.id
    SubnetIds       = join(",", local.restricted_egress_subnet_ids)
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
      ImageVersion:
        Value: !GetAtt MicrovmImage.LatestActiveImageVersion
  YAML

  tags = local.common_tags

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}

data "aws_subnet" "restricted_egress_existing" {
  count = var.existing_vpc_id != null ? length(local.existing_private_subnet_ids) : 0

  id = local.existing_private_subnet_ids[count.index]

  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.existing_vpc_id
      error_message = "Each sandbox subnet must belong to the supplied sandbox VPC."
    }
  }
}

data "aws_subnet" "egress_gateway_nlb" {
  count = length(var.endpoint_subnet_ids)

  id = var.endpoint_subnet_ids[count.index]
}

resource "aws_security_group" "loop_runtime_microvm_endpoint" {
  name        = "${var.deployment_name}-loop-microvm-vpce"
  description = "Private MicroVM endpoint for Loop runtime"
  vpc_id      = var.endpoint_vpc_id
  tags        = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "loop_runtime_microvm_https" {
  security_group_id            = aws_security_group.loop_runtime_microvm_endpoint.id
  referenced_security_group_id = var.runtime_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow Loop runtime to access MicroVMs through PrivateLink."
  tags                         = local.common_tags
}

resource "aws_vpc_endpoint" "loop_runtime_microvm" {
  vpc_id              = var.endpoint_vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.lambda-microvm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = local.main_endpoint_subnet_ids
  security_group_ids  = [aws_security_group.loop_runtime_microvm_endpoint.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "lambda:ConnectMicrovm"
      Resource  = "*"
      Condition = {
        StringEquals = {
          "aws:ResourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
  tags = local.common_tags
}

# --- Sandbox egress gateway ---
# Sandboxes reach the Loop runtime egress proxy (port 4002) through
# PrivateLink: an interface endpoint in the sandbox VPC connects to an
# endpoint service in front of an internal NLB in the main VPC. The proxy
# authorizes each request, so reaching the endpoint grants no credentials.

resource "aws_security_group" "egress_gateway_nlb" {
  name        = "${var.deployment_name}-loop-egress-gateway-nlb"
  description = "Security group for the Loop sandbox egress gateway NLB"
  vpc_id      = var.endpoint_vpc_id

  tags = merge({
    Name = "${var.deployment_name}-loop-egress-gateway-nlb"
  }, local.common_tags)
}

resource "aws_vpc_security_group_egress_rule" "egress_gateway_nlb_to_runtime" {
  security_group_id            = aws_security_group.egress_gateway_nlb.id
  referenced_security_group_id = var.runtime_security_group_id
  from_port                    = local.egress_gateway_port
  to_port                      = local.egress_gateway_port
  ip_protocol                  = "tcp"
  description                  = "Allow the egress gateway NLB to reach Loop runtime tasks."
  tags                         = local.common_tags
}

resource "aws_lb" "egress_gateway" {
  name                             = "${var.deployment_name}-loop-egress"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = local.main_endpoint_subnet_ids
  security_groups                  = [aws_security_group.egress_gateway_nlb.id]
  enable_cross_zone_load_balancing = true

  # PrivateLink traffic is limited by the endpoint service principals and the
  # sandbox endpoint security group. The sandbox subnets vary with
  # existing_vpc_id, so the NLB does not filter this traffic again.
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"

  tags = merge({
    Name = "${var.deployment_name}-loop-egress-gateway"
  }, local.common_tags)
}

resource "aws_lb_target_group" "egress_gateway" {
  name                 = "${var.deployment_name}-loop-egress"
  port                 = local.egress_gateway_port
  protocol             = "TCP"
  target_type          = "ip"
  vpc_id               = var.endpoint_vpc_id
  deregistration_delay = var.egress_gateway_deregistration_delay

  health_check {
    enabled  = true
    protocol = "TCP"
    port     = "traffic-port"
  }

  tags = merge({
    Name = "${var.deployment_name}-loop-egress-gateway"
  }, local.common_tags)
}

resource "aws_lb_listener" "egress_gateway" {
  load_balancer_arn = aws_lb.egress_gateway.arn
  port              = local.egress_gateway_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.egress_gateway.arn
  }

  tags = local.common_tags
}

resource "aws_vpc_endpoint_service" "egress_gateway" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.egress_gateway.arn]
  allowed_principals         = ["arn:${local.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]

  tags = merge({
    Name = "${var.deployment_name}-loop-egress-gateway"
  }, local.common_tags)
}

resource "aws_security_group" "egress_gateway_endpoint" {
  name        = "${var.deployment_name}-loop-egress-gateway-vpce"
  description = "Security group for the Loop sandbox egress gateway endpoint"
  vpc_id      = local.restricted_egress_vpc_id

  tags = merge({
    Name = "${var.deployment_name}-loop-egress-gateway-vpce"
  }, local.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "egress_gateway_endpoint_from_sandbox" {
  security_group_id            = aws_security_group.egress_gateway_endpoint.id
  referenced_security_group_id = aws_security_group.restricted_egress.id
  from_port                    = local.egress_gateway_port
  to_port                      = local.egress_gateway_port
  ip_protocol                  = "tcp"
  description                  = "Allow Loop sandboxes to reach the egress gateway."
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "sandbox_to_egress_gateway" {
  security_group_id            = aws_security_group.restricted_egress.id
  referenced_security_group_id = aws_security_group.egress_gateway_endpoint.id
  from_port                    = local.egress_gateway_port
  to_port                      = local.egress_gateway_port
  ip_protocol                  = "tcp"
  description                  = "Allow Loop sandboxes to reach only the egress gateway."
  tags                         = local.common_tags
}

resource "aws_vpc_endpoint" "egress_gateway" {
  vpc_id              = local.restricted_egress_vpc_id
  service_name        = aws_vpc_endpoint_service.egress_gateway.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false
  subnet_ids          = local.egress_gateway_subnet_ids
  security_group_ids  = [aws_security_group.egress_gateway_endpoint.id]

  lifecycle {
    precondition {
      condition     = length(local.egress_gateway_subnet_ids) > 0
      error_message = "The sandbox VPC needs a subnet in an availability zone served by the egress gateway NLB."
    }
  }

  tags = merge({
    Name = "${var.deployment_name}-loop-egress-gateway"
  }, local.common_tags)
}
