# Lambda ingress after the ordering fix. The distribution depends on the
# stage and invoke permission, and both use create_before_destroy.

resource "terraform_data" "slow" {
  input = "lambda"
}

resource "terraform_data" "rest" {
  input = "rest"
}

resource "terraform_data" "deployment" {
  input = terraform_data.rest.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "stage" {
  input = terraform_data.deployment.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "permission" {
  input = terraform_data.rest.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "terraform_data" "cloudfront" {
  input = {
    origin = terraform_data.rest.id
  }

  depends_on = [
    terraform_data.stage,
    terraform_data.permission,
  ]
}
