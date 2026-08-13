# ALB path routing (evaluated by ascending priority; unmatched → braintrust-api).
#
# Each route requires:
#   - path:         path pattern to match
#   - target_group: target group ARN to forward to
#   - priority:     explicit ALB listener-rule priority (must be unique)
#
# Optional:
#   - method: HTTP method to match (e.g. "POST"); omit to match any method
#
# for_each keys are stable METHOD:path strings so adding or reordering routes
# does not reshuffle keys and force listener-rule replace.
#
# Priorities are explicit and gapped (not idx+1). Gaps let new routes claim an
# unused priority without touching existing ones — pick a free gap (e.g. 105).
# Values start at 100 so the upgrade from the old 1..N scheme does not collide
# with still-held low numbers during apply.
#
# Do not renumber existing rules in the same apply when the new priorities
# overlap still-held ones (e.g. shifting 1→2 while another rule is still at 2).
# The AWS provider updates aws_lb_listener_rule.priority via SetRulePriorities
# for that one rule only; unspecified rules keep their current priority, so
# overlapping remumbers fail with PriorityInUse. Remap only into a free,
# non-overlapping range (or append into unused numbers).

locals {
  alb_path_routes = [
    # braintrust-api-ingest
    { path = "/logs3", method = "POST", priority = 100, target_group = aws_lb_target_group.braintrust_api_ingest.arn },
    { path = "/otel/v1/traces", method = "POST", priority = 110, target_group = aws_lb_target_group.braintrust_api_ingest.arn },
    { path = "/attachment", method = "POST", priority = 120, target_group = aws_lb_target_group.braintrust_api_ingest.arn },
    { path = "/attachment/status", method = "POST", priority = 130, target_group = aws_lb_target_group.braintrust_api_ingest.arn },

    # braintrust-api-background
    { path = "/v1/eval", method = "POST", priority = 200, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/eval/*", method = "POST", priority = 210, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/eval", method = "POST", priority = 220, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/sandbox", method = "POST", priority = 230, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/use", method = "POST", priority = 240, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/invoke-async-batch", method = "POST", priority = 250, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/insert-functions", method = "POST", priority = 260, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/automation/logs/trigger", method = "POST", priority = 270, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/proxy/chat/completions", priority = 280, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/proxy/responses", priority = 290, target_group = aws_lb_target_group.braintrust_api_background.arn },
  ]

  alb_path_listener_rules = {
    for route in local.alb_path_routes :
    "${try(route.method, "ANY")}:${route.path}" => merge(
      { method = null },
      route,
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
