# Lambda ingress as released before the cutover edge existed.
# The distribution references the REST API only. The stage and invoke
# permission have no create_before_destroy.

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
}

resource "terraform_data" "permission" {
  input = terraform_data.rest.id
}

resource "terraform_data" "cloudfront" {
  input = {
    origin = terraform_data.rest.id
  }
}
