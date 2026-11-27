# ECS ingress after the ordering fix. API Gateway resources are removed.
# The distribution update waits on `slow`, standing in for the resources the
# real distribution update waits on, then the stage and permission may go.

resource "terraform_data" "slow" {
  input = "ecs"
}

resource "terraform_data" "rest" {
  count = 0
  input = "rest"
}

resource "terraform_data" "deployment" {
  count = 0
  input = "deployment"

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "stage" {
  count = 0
  input = "stage"

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "permission" {
  count = 0
  input = "permission"

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "cloudfront" {
  input = {
    origin = terraform_data.slow.output
  }

  depends_on = [
    terraform_data.stage,
    terraform_data.permission,
  ]
}
