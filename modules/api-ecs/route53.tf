data "aws_route53_zone" "validation" {
  count = var.create_acm_certificate || var.create_dns_record ? 1 : 0

  name         = local.route53_zone_fqdn != null ? "${local.route53_zone_fqdn}." : "invalid.local."
  private_zone = false
}

resource "aws_acm_certificate" "alb" {
  count             = var.create_acm_certificate ? 1 : 0
  domain_name       = local.certificate_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.create_acm_certificate ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.validation[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_route53_record" "alb_alias" {
  count = var.create_dns_record ? 1 : 0

  zone_id = data.aws_route53_zone.validation[0].zone_id
  name    = local.certificate_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.api_ecs.dns_name
    zone_id                = aws_lb.api_ecs.zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate_validation" "alb" {
  count = var.create_acm_certificate ? 1 : 0

  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
