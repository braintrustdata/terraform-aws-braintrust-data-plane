locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  # When both an ACM certificate and a custom domain are provided, the ALB serves
  # HTTPS on 443 and the API URL points at the custom domain so the certificate
  # validates. Otherwise the ALB serves plain HTTP on 80 via its AWS DNS name.
  alb_https_enabled = var.alb_certificate_arn != null && var.alb_custom_domain != null
  alb_listener_port = local.alb_https_enabled ? 443 : 80
  api_ecs_url       = local.alb_https_enabled ? "https://${var.alb_custom_domain}" : "http://${aws_lb.api_ecs.dns_name}"
}
