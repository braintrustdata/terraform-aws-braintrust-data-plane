# PrivateLink sandwich (Netflix NLB→ALB pattern): quarantine VPC reaches the
# private gateway ALB without VPC peering.
#
# Provider (main VPC): internal NLB → target_type=alb (gateway ALB) → VPC
# endpoint service (acceptance_required=false for same-account) + allowed
# principal for this account root. Consumer (quarantine VPC): interface VPC
# endpoint → QUARANTINE_PROXY_URL uses http://<vpce-dns>/v1/proxy.
#
# Only when use_private_gateway_quarantine_proxy wires to the private gateway
# and both VPCs are module-managed (create_vpc + module quarantine). Existing
# VPC / existing quarantine require a manual endpoint (use the endpoint service
# name output) and an explicit quarantine_proxy_url.

locals {
  create_quarantine_gateway_privatelink = (
    local.wire_quarantine_to_private_gateway &&
    var.create_vpc &&
    local.create_quarantine_vpc
  )
}

resource "aws_security_group" "gateway_quarantine_privatelink_nlb" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  name        = "${var.deployment_name}-gw-q-pl-nlb"
  description = "Security group for quarantine-to-gateway PrivateLink NLB"
  vpc_id      = local.main_vpc_id

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl-nlb"
  }, local.all_custom_tags)
}

# No broad 0.0.0.0/0 :80 ingress on the NLB SG. PrivateLink consumer traffic is
# admitted because enforce_security_group_inbound_rules_on_private_link_traffic
# is "off" on the NLB (AWS endpoint-service pattern; consumer source IPs are not
# usefully matchable via NLB SG rules). Egress below still scopes NLB→ALB to :80.

resource "aws_vpc_security_group_egress_rule" "gateway_quarantine_privatelink_nlb_to_alb" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  security_group_id            = aws_security_group.gateway_quarantine_privatelink_nlb[0].id
  referenced_security_group_id = module.gateway_alb[0].gateway_alb_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP from the PrivateLink NLB to the gateway ALB."

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl-nlb-to-alb"
  }, local.all_custom_tags)
}

resource "aws_vpc_security_group_ingress_rule" "gateway_alb_from_quarantine_privatelink_nlb" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  security_group_id            = module.gateway_alb[0].gateway_alb_security_group_id
  referenced_security_group_id = aws_security_group.gateway_quarantine_privatelink_nlb[0].id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP from quarantine PrivateLink NLB."

  tags = merge({
    Name = "${var.deployment_name}-gateway-alb-from-gw-q-pl-nlb"
  }, local.all_custom_tags)
}

resource "aws_lb" "gateway_quarantine_privatelink" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  name               = "${var.deployment_name}-gw-q-pl"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.gateway_quarantine_privatelink_nlb[0].id]
  # PrivateLink traffic bypasses NLB SG evaluation; see comment above the NLB SG.
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"
  subnets                                                      = local.main_vpc_private_subnet_ids

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl"
  }, local.all_custom_tags)
}

resource "aws_lb_target_group" "gateway_quarantine_privatelink_alb" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

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
  }, local.all_custom_tags)
}

resource "aws_lb_target_group_attachment" "gateway_quarantine_privatelink_alb" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  target_group_arn = aws_lb_target_group.gateway_quarantine_privatelink_alb[0].arn
  target_id        = module.gateway_alb[0].gateway_alb_arn
  port             = 80
}

resource "aws_lb_listener" "gateway_quarantine_privatelink_http" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  load_balancer_arn = aws_lb.gateway_quarantine_privatelink[0].arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway_quarantine_privatelink_alb[0].arn
  }
}

resource "aws_vpc_endpoint_service" "gateway_quarantine" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.gateway_quarantine_privatelink[0].arn]

  tags = merge({
    Name = "${var.deployment_name}-gw-q-pl"
  }, local.all_custom_tags)
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
  vpc_id      = module.quarantine_vpc[0].vpc_id

  tags = merge({
    Name = "${var.deployment_name}-q-gw-pl-vpce"
  }, local.all_custom_tags)
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
  }, local.all_custom_tags)
}

resource "aws_vpc_security_group_egress_rule" "quarantine_gateway_privatelink_endpoint_all" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  security_group_id = aws_security_group.quarantine_gateway_privatelink_endpoint[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from the quarantine gateway VPC endpoint."

  tags = merge({
    Name = "${var.deployment_name}-q-gw-pl-vpce-egress"
  }, local.all_custom_tags)
}

resource "aws_vpc_endpoint" "quarantine_gateway" {
  count = local.create_quarantine_gateway_privatelink ? 1 : 0

  vpc_id              = module.quarantine_vpc[0].vpc_id
  service_name        = aws_vpc_endpoint_service.gateway_quarantine[0].service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false
  subnet_ids = [
    module.quarantine_vpc[0].private_subnet_1_id,
    module.quarantine_vpc[0].private_subnet_2_id,
    module.quarantine_vpc[0].private_subnet_3_id,
  ]
  security_group_ids = [aws_security_group.quarantine_gateway_privatelink_endpoint[0].id]

  # Ensure the account root is allow-listed before the consumer VPCE is created.
  depends_on = [aws_vpc_endpoint_service_allowed_principal.gateway_quarantine_current_account]

  tags = merge({
    Name = "${var.deployment_name}-q-gw-pl"
  }, local.all_custom_tags)
}
