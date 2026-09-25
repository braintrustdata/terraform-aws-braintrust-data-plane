# Preserve existing listener-rule state across the for_each key rename so upgrades
# update in place instead of destroy/recreate (which can briefly misroute traffic).
# Priorities are remapped separately in alb-path-routes.tf to gapped values >= 100
# so SetRulePriorities does not collide with still-held 1..N priorities.
# Remove these moved blocks after all stacks have applied once.
moved {
  from = aws_lb_listener_rule.alb_path_routes["1"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/logs3"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["2"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/otel/v1/*"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["3"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/attachment"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["4"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/attachment/status"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["5"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/v1/eval"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["6"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/v1/eval/*"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["7"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/function/eval"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["8"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/function/sandbox"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["9"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/function/use"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["10"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/function/invoke-async-batch"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["11"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/function/insert-functions"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["12"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/automation/logs/trigger"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["13"]
  to   = aws_lb_listener_rule.alb_path_routes["ANY:/v1/proxy/chat/completions"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["14"]
  to   = aws_lb_listener_rule.alb_path_routes["ANY:/v1/proxy/responses"]
}
moved {
  from = aws_lb_listener_rule.alb_path_routes["15"]
  to   = aws_lb_listener_rule.alb_path_routes["POST:/logs3/overflow"]
}
