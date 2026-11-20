# Public mode retains quarantine-to-gateway PrivateLink.
# Private mode uses create_quarantine_api_access for one API ALB endpoint.
# The endpoint and NLB keep their released addresses in both modes.
# Managed and supplied VPCs use the same subnet and authorization checks.

locals {
  create_quarantine_gateway_privatelink = (
    (local.wire_quarantine_to_private_gateway || local.create_private_quarantine_api_access) &&
    var.enable_quarantine_vpc
  )
  privatelink_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, local.all_custom_tags)
}

# Use fixed list lengths, not subnet IDs as for_each keys: callers may pass
# subnets created in the same apply. Managed subnets are read after creation.
# Validate the same network requirements regardless of who owns the VPCs.
data "aws_subnet" "quarantine_privatelink_main" {
  count = local.create_quarantine_gateway_privatelink ? length(local.main_vpc_private_subnet_ids) : 0

  id = local.main_vpc_private_subnet_ids[count.index]

  lifecycle {
    precondition {
      condition = (
        try(trimspace(local.main_vpc_id) != "", false) &&
        alltrue([for id in local.main_vpc_private_subnet_ids : try(trimspace(id) != "", false)]) &&
        length(distinct(local.main_vpc_private_subnet_ids)) == length(local.main_vpc_private_subnet_ids)
      )
      error_message = "Quarantine PrivateLink requires a nonempty main VPC ID and distinct, nonempty main private subnet IDs."
    }
    postcondition {
      condition     = self.vpc_id == local.main_vpc_id
      error_message = "Each main PrivateLink subnet must belong to the main VPC."
    }
  }
}

data "aws_subnet" "quarantine_privatelink_quarantine" {
  count = local.create_quarantine_gateway_privatelink ? length(local.quarantine_vpc_private_subnet_ids) : 0

  id = local.quarantine_vpc_private_subnet_ids[count.index]

  lifecycle {
    precondition {
      condition = (
        try(trimspace(local.quarantine_vpc_id) != "", false) &&
        alltrue([for id in local.quarantine_vpc_private_subnet_ids : try(trimspace(id) != "", false)]) &&
        length(distinct(local.quarantine_vpc_private_subnet_ids)) == length(local.quarantine_vpc_private_subnet_ids)
      )
      error_message = "Quarantine PrivateLink requires a nonempty quarantine VPC ID and distinct, nonempty quarantine private subnet IDs."
    }
    postcondition {
      condition     = self.vpc_id == local.quarantine_vpc_id
      error_message = "Each quarantine PrivateLink subnet must belong to the quarantine VPC."
    }
  }
}

# Validate the selected PrivateLink path.
resource "terraform_data" "quarantine_privatelink_requirements" {
  count = (
    (!var.enable_private_dataplane && var.use_private_gateway_quarantine_proxy) ||
    local.create_quarantine_gateway_privatelink
  ) ? 1 : 0

  lifecycle {
    precondition {
      condition = (
        var.use_global_ai_gateway_origin ||
        local.quarantine_proxy_url_override != null ||
        local.create_quarantine_gateway_privatelink
      )
      error_message = "use_private_gateway_quarantine_proxy requires enable_quarantine_vpc to create PrivateLink, or an explicit quarantine_proxy_url."
    }
    precondition {
      condition = (
        length(distinct(data.aws_subnet.quarantine_privatelink_main[*].availability_zone)) == length(data.aws_subnet.quarantine_privatelink_main) &&
        length(distinct(data.aws_subnet.quarantine_privatelink_quarantine[*].availability_zone)) == length(data.aws_subnet.quarantine_privatelink_quarantine)
      )
      error_message = "Quarantine PrivateLink requires the private subnets in each VPC to be in distinct availability zones."
    }
    precondition {
      condition = alltrue([
        for subnet in data.aws_subnet.quarantine_privatelink_quarantine :
        contains(data.aws_subnet.quarantine_privatelink_main[*].availability_zone, subnet.availability_zone)
      ])
      error_message = "Each quarantine PrivateLink subnet must be in an availability zone enabled on the main VPC NLB. Supply main and quarantine subnets in matching availability zones."
    }
  }
}

resource "aws_security_group" "gateway_quarantine_privatelink_nlb" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  name        = "${var.deployment_name}-gw-q-pl-nlb"
  description = "Security group for quarantine-to-gateway PrivateLink NLB"
  vpc_id      = local.main_vpc_id

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl-nlb"
  }, local.privatelink_tags)
}

# No broad 0.0.0.0/0 :80 ingress on the NLB SG. PrivateLink consumer traffic is
# admitted because enforce_security_group_inbound_rules_on_private_link_traffic
# is "off" on the NLB (AWS endpoint-service pattern; consumer source IPs are not
# usefully matchable via NLB SG rules). Egress below still scopes NLB→ALB to :80.

resource "aws_vpc_security_group_egress_rule" "gateway_quarantine_privatelink_nlb_to_alb" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  security_group_id            = aws_security_group.gateway_quarantine_privatelink_nlb[0].id
  referenced_security_group_id = var.enable_private_dataplane ? module.api_ecs[0].alb_security_group_id : module.gateway_alb[0].gateway_alb_security_group_id
  from_port                    = var.enable_private_dataplane ? 8000 : 80
  to_port                      = var.enable_private_dataplane ? 8000 : 80
  ip_protocol                  = "tcp"
  description                  = var.enable_private_dataplane ? "Allow HTTP from the PrivateLink NLB to the API ALB." : "Allow HTTP from the PrivateLink NLB to the gateway ALB."

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl-nlb-to-alb"
  }, local.privatelink_tags)
}

resource "aws_vpc_security_group_ingress_rule" "gateway_alb_from_quarantine_privatelink_nlb" {
  count = local.create_quarantine_gateway_privatelink && !var.enable_private_dataplane ? 1 : 0

  security_group_id            = module.gateway_alb[0].gateway_alb_security_group_id
  referenced_security_group_id = aws_security_group.gateway_quarantine_privatelink_nlb[0].id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP from quarantine PrivateLink NLB."

  tags = merge({
    Name = "${var.deployment_name}-gateway-alb-from-gw-q-pl-nlb"
  }, local.privatelink_tags)
}

resource "aws_lb" "gateway_quarantine_privatelink" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  name                             = "${var.deployment_name}-gw-q-pl"
  internal                         = true
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = true
  security_groups                  = [aws_security_group.gateway_quarantine_privatelink_nlb[0].id]
  # PrivateLink traffic bypasses NLB SG evaluation; see comment above the NLB SG.
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"
  subnets                                                      = local.main_vpc_private_subnet_ids

  # Validate VPC membership and AZ coverage before provisioning the path.
  depends_on = [terraform_data.quarantine_privatelink_requirements]

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl"
  }, local.privatelink_tags)
}

resource "aws_lb_target_group" "gateway_quarantine_privatelink_alb" {
  count = local.create_quarantine_gateway_privatelink && !var.enable_private_dataplane ? 1 : 0

  name        = "${var.deployment_name}-gw-q-pl-alb"
  port        = 80
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = local.main_vpc_id

  health_check {
    enabled  = true
    protocol = "HTTP"
    path     = "/health"
    matcher  = "200-399"
  }

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl-alb"
  }, local.privatelink_tags)
}

resource "aws_lb_target_group_attachment" "gateway_quarantine_privatelink_alb" {
  count = local.create_quarantine_gateway_privatelink && !var.enable_private_dataplane ? 1 : 0

  target_group_arn = aws_lb_target_group.gateway_quarantine_privatelink_alb[0].arn
  target_id        = module.gateway_alb[0].gateway_alb_arn
  port             = 80

  # ALB must have a listener before NLB alb-target registration (same ordering
  # concern as gateway-ecs waiting on the HTTP listener).
  depends_on = [module.gateway_alb]
}

resource "aws_lb_target_group" "api_quarantine_privatelink_alb" {
  count = local.create_private_quarantine_api_access ? 1 : 0

  name        = "${var.deployment_name}-api-q-pl-alb"
  port        = 8000
  protocol    = "TCP"
  target_type = "alb"
  vpc_id      = local.main_vpc_id

  health_check {
    enabled  = true
    protocol = "HTTP"
    path     = "/"
    matcher  = "200-399"
  }

  tags = merge({
    Name = "${var.deployment_name}-api-q-pl-alb"
  }, local.privatelink_tags)
}

resource "aws_lb_target_group_attachment" "api_quarantine_privatelink_alb" {
  count = local.create_private_quarantine_api_access ? 1 : 0

  target_group_arn = aws_lb_target_group.api_quarantine_privatelink_alb[0].arn
  target_id        = module.api_ecs[0].quarantine_alb_arn
  port             = 8000
}

resource "aws_lb_listener" "gateway_quarantine_privatelink_http" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  load_balancer_arn = aws_lb.gateway_quarantine_privatelink[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = var.enable_private_dataplane ? aws_lb_target_group.api_quarantine_privatelink_alb[0].arn : aws_lb_target_group.gateway_quarantine_privatelink_alb[0].arn
  }
}

resource "aws_vpc_endpoint_service" "gateway_quarantine" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.gateway_quarantine_privatelink[0].arn]

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl"
  }, local.privatelink_tags)
}

# Same-account consumers still need an allowed principal; acceptance_required=false
# only skips manual acceptance after discoverability is granted.
resource "aws_vpc_endpoint_service_allowed_principal" "gateway_quarantine_current_account" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  vpc_endpoint_service_id = aws_vpc_endpoint_service.gateway_quarantine[0].id
  principal_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}

resource "aws_security_group" "quarantine_gateway_privatelink_endpoint" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  name        = "${var.deployment_name}-q-gw-pl-vpce"
  description = "Security group for quarantine VPC endpoint to private gateway"
  vpc_id      = local.quarantine_vpc_id

  tags = merge({
    Name = "${var.deployment_name}-q-gw-pl-vpce"
  }, local.privatelink_tags)
}

resource "aws_vpc_security_group_ingress_rule" "quarantine_gateway_privatelink_endpoint_http" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  security_group_id            = aws_security_group.quarantine_gateway_privatelink_endpoint[0].id
  referenced_security_group_id = module.services_common.quarantine_lambda_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP from quarantine Lambdas to the private gateway VPC endpoint."

  tags = merge({
    Name = "${var.deployment_name}-q-gw-pl-vpce-http"
  }, local.privatelink_tags)
}

resource "aws_vpc_security_group_egress_rule" "quarantine_gateway_privatelink_endpoint_all" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  security_group_id = aws_security_group.quarantine_gateway_privatelink_endpoint[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from the quarantine gateway VPC endpoint."

  tags = merge({
    Name = "${var.deployment_name}-q-gw-pl-vpce-egress"
  }, local.privatelink_tags)
}

resource "aws_vpc_endpoint" "quarantine_gateway" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  vpc_id              = local.quarantine_vpc_id
  service_name        = aws_vpc_endpoint_service.gateway_quarantine[0].service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false
  subnet_ids          = local.quarantine_vpc_private_subnet_ids
  security_group_ids  = [aws_security_group.quarantine_gateway_privatelink_endpoint[0].id]

  # These rules and the forwarding path are not otherwise dependencies of the
  # endpoint. Finish them before exposing its URL to callers.
  depends_on = [
    aws_vpc_endpoint_service_allowed_principal.gateway_quarantine_current_account,
    aws_lb_listener.gateway_quarantine_privatelink_http,
    aws_lb_target_group_attachment.gateway_quarantine_privatelink_alb,
    aws_lb_target_group_attachment.api_quarantine_privatelink_alb,
    aws_vpc_security_group_egress_rule.gateway_quarantine_privatelink_nlb_to_alb,
    aws_vpc_security_group_ingress_rule.gateway_alb_from_quarantine_privatelink_nlb,
    aws_vpc_security_group_ingress_rule.quarantine_gateway_privatelink_endpoint_http,
    aws_vpc_security_group_egress_rule.quarantine_gateway_privatelink_endpoint_all,
    module.gateway_ecs,
  ]

  tags = merge({
    Name = "${var.deployment_name}-q-gw-pl"
  }, local.privatelink_tags)
}
