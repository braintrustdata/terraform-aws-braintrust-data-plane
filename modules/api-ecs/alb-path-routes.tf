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
# Priorities are explicit (not idx+1). The AWS provider updates
# aws_lb_listener_rule.priority via SetRulePriorities for that one rule only;
# unspecified rules keep their current priority. Index-derived priorities would
# shift neighbors on insert and fail with PriorityInUse. Keep the historical
# 1..N values here so this upgrade only renames for_each keys (via moved
# blocks) without priority churn. When adding a route, assign an unused
# priority (append with max+1, or renumber with gaps if inserting mid-list).

locals {
  alb_path_routes = [
    # braintrust-api-ingest
    { path = "/logs3", method = "POST", priority = 1, target_group = aws_lb_target_group.braintrust_api_ingest.arn },
    { path = "/otel/v1/traces", method = "POST", priority = 2, target_group = aws_lb_target_group.braintrust_api_ingest.arn },
    { path = "/attachment", method = "POST", priority = 3, target_group = aws_lb_target_group.braintrust_api_ingest.arn },
    { path = "/attachment/status", method = "POST", priority = 4, target_group = aws_lb_target_group.braintrust_api_ingest.arn },

    # braintrust-api-background
    { path = "/v1/eval", method = "POST", priority = 5, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/eval/*", method = "POST", priority = 6, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/eval", method = "POST", priority = 7, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/sandbox", method = "POST", priority = 8, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/use", method = "POST", priority = 9, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/invoke-async-batch", method = "POST", priority = 10, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/function/insert-functions", method = "POST", priority = 11, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/automation/logs/trigger", method = "POST", priority = 12, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/proxy/chat/completions", priority = 13, target_group = aws_lb_target_group.braintrust_api_background.arn },
    { path = "/v1/proxy/responses", priority = 14, target_group = aws_lb_target_group.braintrust_api_background.arn },
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
