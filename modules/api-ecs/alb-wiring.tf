# Keep explicit dependencies on the independently managed ALB configuration.
# ECS requires each target group to be associated with a listener before service
# creation, and these values carry those cross-module dependencies into ECS.
resource "terraform_data" "alb_http_listener" {
  input = var.alb_http_listener_arn
}

resource "terraform_data" "alb_path_listener_rules" {
  input = var.alb_path_listener_rule_arns
}
