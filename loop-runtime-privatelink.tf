# Loop v2 restricted-egress consumer for the shared gateway PrivateLink
# sandwich. The NLB + endpoint service stay in quarantine-privatelink.tf
# (gateway_quarantine_* names are the shared provider).
#
# Restricted MicroVMs live in the 10.255 connector VPC (no NAT, DNS * →
# NXDOMAIN). This file adds an Interface VPCE in that VPC and points
# LOOP_RUNTIME_AI_PROXY_URL at http://<vpce-dns>/v1/proxy. Loop v2 needs
# the private gateway and cannot use AI Proxy. Do not fall back to the
# Function URL when restricted was requested but the VPCE cannot be created.

locals {
  create_loop_gateway_privatelink = (
    local.create_loop_runtime &&
    var.loop_runtime_sandbox_egress_mode != "internet" &&
    local.create_ai_gateway &&
    var.create_vpc &&
    !var.use_global_ai_gateway_origin
  )

  loop_runtime_privatelink_proxy_url = try(
    "http://${aws_vpc_endpoint.loop_gateway[0].dns_entry[0].dns_name}/v1/proxy",
    null
  )

  # Precedence: explicit override → Loop VPCE /v1/proxy when restricted
  # PrivateLink is created → else Function URL (internet-mode Loop only).
  loop_runtime_ai_proxy_url = (
    var.loop_runtime_ai_proxy_url != null ? var.loop_runtime_ai_proxy_url : (
      local.create_loop_gateway_privatelink
      ? local.loop_runtime_privatelink_proxy_url
      : local.self_hosted_ai_proxy_url
    )
  )
}

# Fail when restricted Loop is on but this module cannot create the VPCE and
# there is no URL override. use_global_ai_gateway_origin is not a no-op here:
# restricted MicroVMs cannot reach a hosted gateway.
resource "terraform_data" "loop_privatelink_requirements" {
  count = (
    local.create_loop_runtime &&
    var.loop_runtime_sandbox_egress_mode != "internet"
  ) ? 1 : 0

  lifecycle {
    precondition {
      condition = (
        var.loop_runtime_ai_proxy_url != null ||
        local.create_loop_gateway_privatelink
      )
      error_message = "Restricted Loop runtime egress needs a private gateway PrivateLink path (create_ai_gateway, a module-managed main VPC, and not use_global_ai_gateway_origin), or set loop_runtime_ai_proxy_url. Loop v2 cannot use AI Proxy."
    }
  }
}

resource "aws_vpc_endpoint" "loop_gateway" {
  count = local.create_loop_gateway_privatelink ? 1 : 0

  vpc_id              = module.loop_runtime_sandbox_aws_microvm[0].restricted_egress_vpc_id
  service_name        = aws_vpc_endpoint_service.gateway_quarantine[0].service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false
  subnet_ids          = module.loop_runtime_sandbox_aws_microvm[0].restricted_egress_subnet_ids
  security_group_ids  = [module.loop_runtime_sandbox_aws_microvm[0].loop_gateway_privatelink_endpoint_security_group_id]

  depends_on = [aws_vpc_endpoint_service_allowed_principal.gateway_quarantine_current_account]

  tags = merge({
    Name = "${var.deployment_name}-loop-gw-pl"
  }, local.privatelink_tags)
}
