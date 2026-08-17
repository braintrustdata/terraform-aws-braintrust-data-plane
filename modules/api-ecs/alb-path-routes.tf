# ALB path routing (evaluated by priority; lower number wins).
# Unmatched requests fall through to the listener default action → braintrust-api.
#
# When create_rust_api_ingest is true, ingest path rules use a weighted forward
# across the TypeScript and Rust target groups (rust_api_ingest_traffic_weight).
# Non-ingest routes are unchanged.

locals {
  rust_api_ingest_traffic_weight = var.create_rust_api_ingest ? var.rust_api_ingest_traffic_weight : 0
  ts_api_ingest_traffic_weight   = 100 - local.rust_api_ingest_traffic_weight

  ingest_target_groups = var.create_rust_api_ingest ? [
    {
      arn    = aws_lb_target_group.braintrust_api_ingest.arn
      weight = local.ts_api_ingest_traffic_weight
    },
    {
      arn    = aws_lb_target_group.braintrust_api_rust_ingest[0].arn
      weight = local.rust_api_ingest_traffic_weight
    },
    ] : [
    {
      arn = aws_lb_target_group.braintrust_api_ingest.arn
    },
  ]

  alb_path_routes = [
    # braintrust-api-ingest (weighted TS/Rust when create_rust_api_ingest)
    { path = "/logs3", method = "POST", target_groups = local.ingest_target_groups },
    { path = "/otel/v1/*", method = "POST", target_groups = local.ingest_target_groups },
    { path = "/attachment", method = "POST", target_groups = local.ingest_target_groups },
    { path = "/attachment/status", method = "POST", target_groups = local.ingest_target_groups },

    # braintrust-api-background
    { path = "/v1/eval", method = "POST", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/v1/eval/*", method = "POST", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/function/eval", method = "POST", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/function/sandbox", method = "POST", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/function/use", method = "POST", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/function/invoke-async-batch", method = "POST", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/function/insert-functions", method = "POST", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/automation/logs/trigger", method = "POST", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/v1/proxy/chat/completions", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/v1/proxy/responses", target_groups = [{ arn = aws_lb_target_group.braintrust_api_background.arn }] },
    { path = "/logs3/overflow", method = "POST", target_groups = local.ingest_target_groups },
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
      dynamic "target_group" {
        for_each = each.value.target_groups

        content {
          arn    = target_group.value.arn
          weight = try(target_group.value.weight, null)
        }
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
