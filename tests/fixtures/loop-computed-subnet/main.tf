variable "deployment_name" {
  type = string
}

variable "microvm_version_tag" {
  type = string
}

variable "endpoint_vpc_id" {
  type = string
}

variable "endpoint_subnet_ids" {
  type = list(string)
}

variable "runtime_security_group_id" {
  type = string
}

resource "aws_subnet" "third" {
  vpc_id            = "vpc-0123456789abcdef0"
  cidr_block        = "10.1.3.0/24"
  availability_zone = "us-east-1c"
}

# A known id would fail this check during planning. An id that is unknown until
# apply defers it, which is the case this fixture exists to plan.
resource "terraform_data" "third_subnet_id_is_unknown_until_apply" {
  lifecycle {
    precondition {
      condition     = aws_subnet.third.id == "known-id-would-fail-this-check"
      error_message = "aws_subnet.third.id was known during planning, so this does not exercise a computed subnet count."
    }
  }
}

module "sandbox" {
  source = "../../../modules/loop-runtime-sandbox-aws-microvm"

  deployment_name           = var.deployment_name
  microvm_version_tag       = var.microvm_version_tag
  endpoint_vpc_id           = var.endpoint_vpc_id
  endpoint_subnet_ids       = var.endpoint_subnet_ids
  runtime_security_group_id = var.runtime_security_group_id

  existing_vpc_id              = "vpc-0123456789abcdef0"
  existing_private_subnet_1_id = "subnet-0123456789abcdef0"
  existing_private_subnet_2_id = "subnet-0123456789abcdef1"
  existing_private_subnet_3_id = aws_subnet.third.id
}
