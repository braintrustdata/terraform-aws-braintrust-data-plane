data "aws_region" "loop_runtime" {}

resource "aws_security_group" "loop_runtime_microvm_endpoint" {
  count = local.create_loop_runtime ? 1 : 0

  name        = "${var.deployment_name}-loop-microvm-vpce"
  description = "Private MicroVM endpoint for Loop runtime"
  vpc_id      = local.main_vpc_id
  tags        = merge({ BraintrustDeploymentName = var.deployment_name }, local.all_custom_tags)
}

resource "aws_vpc_security_group_ingress_rule" "loop_runtime_microvm_https" {
  count = local.create_loop_runtime ? 1 : 0

  security_group_id            = aws_security_group.loop_runtime_microvm_endpoint[0].id
  referenced_security_group_id = module.loop_runtime_ecs[0].task_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow Loop runtime to access MicroVMs through PrivateLink."
  tags                         = merge({ BraintrustDeploymentName = var.deployment_name }, local.all_custom_tags)
}

resource "aws_vpc_endpoint" "loop_runtime_microvm" {
  count = local.create_loop_runtime ? 1 : 0

  vpc_id              = local.main_vpc_id
  service_name        = "com.amazonaws.${data.aws_region.loop_runtime.region}.lambda-microvm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = local.main_vpc_private_subnet_ids
  security_group_ids  = [aws_security_group.loop_runtime_microvm_endpoint[0].id]

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
  tags = merge({ BraintrustDeploymentName = var.deployment_name }, local.all_custom_tags)
}

resource "aws_vpc_security_group_ingress_rule" "gateway_from_loop_runtime" {
  count = local.create_loop_runtime && local.create_ai_gateway ? 1 : 0

  security_group_id            = module.gateway_alb[0].gateway_alb_security_group_id
  referenced_security_group_id = module.loop_runtime_ecs[0].task_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow Loop runtime to access the private gateway."
  tags                         = merge({ BraintrustDeploymentName = var.deployment_name }, local.all_custom_tags)
}
