# ALB path routing (evaluated top-to-bottom; list order = rule priority).
# Unmatched requests fall through to the listener default action → braintrust-api.
#
# Each route requires:
#   - path:         path pattern to match
#   - target_group: target group ARN to forward to
#
# Optional:
#   - method: HTTP method to match (e.g. "POST"); omit to match any method

locals {
  alb_path_routes = [
    # braintrust-api-ingest
    { path = "/logs3", method = "POST", target_group = aws_lb_target_group.braintrust_api_ingest.arn },
    { path = "/otel/v1/traces", method = "POST", target_group = aws_lb_target_group.braintrust_api_ingest.arn },

    # braintrust-api-background
    { path = "/v1/eval", method = "POST", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/eval/*", method = "POST", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/eval", method = "POST", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/sandbox", method = "POST", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/use", method = "POST", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/invoke-async-batch", method = "POST", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/insert-functions", method = "POST", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/automation/logs/trigger", method = "POST", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/proxy/chat/completions", target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/proxy/responses", target_group = aws_lb_target_group.braintrust_api_background.arn },
  ]

  alb_path_listener_rules = {
    for idx, route in local.alb_path_routes :
    tostring(idx + 1) => merge(
      { method = null },
      route,
      { priority = idx + 1 },
    )
  }
}

resource "aws_lb_listener_rule" "alb_path_routes" {
  for_each = local.alb_path_listener_rules

  listener_arn = aws_lb_listener.api_ecs_http.arn
  priority     = each.value.priority

  action {
    type = "forward"
    forward {
      target_group {
        arn = each.value.target_group
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.method != null ? [each.value.method] : []

    content {
      http_request_method {
        values = [condition.value]
      }
    }
  }

  condition {
    path_pattern {
      values = [each.value.path]
    }
  }
}
