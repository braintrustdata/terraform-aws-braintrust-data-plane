# ECS CreateService requires target groups to already be associated with the ALB
# listener (default action or path rules). Those resources live in api-ecs-alb;
# terraform_data turns the passed ARNs into something services can depends_on.
resource "terraform_data" "alb_listener_ready" {
  input = var.alb_listener_arn
}

resource "terraform_data" "alb_path_rules_ready" {
  input = var.alb_path_listener_rule_arns
}
