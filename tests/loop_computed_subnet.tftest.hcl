mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_cloudformation_stack" {
    defaults = {
      outputs = {
        ImageArn            = "arn:aws:lambda:us-east-1:123456789012:microvm-image:bt-loop-bt-test"
        ImageVersion        = "1"
        NetworkConnectorArn = "arn:aws:lambda:us-east-1:123456789012:network-connector:bt-loop-bt-test-restricted-egress"
      }
    }
  }
  mock_resource "aws_vpc_endpoint" {
    defaults = {
      dns_entry = [
        {
          dns_name       = "vpce-0123456789abcdef0-abcdefgh.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com"
          hosted_zone_id = "Z7HUB22UULQXV"
        },
      ]
    }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-test-loop-egress/1111111111111111" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222" }
  }
}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  deployment_name           = "bt-test"
  microvm_version_tag       = "test"
  endpoint_vpc_id           = "vpc-11111111111111111"
  endpoint_subnet_ids       = ["subnet-11111111111111111", "subnet-22222222222222222", "subnet-33333333333333333"]
  runtime_security_group_id = "sg-11111111111111111"
}

override_data {
  target = module.sandbox.data.aws_subnet.egress_gateway_nlb[0]
  values = { availability_zone = "us-east-1a" }
}

override_data {
  target = module.sandbox.data.aws_subnet.egress_gateway_nlb[1]
  values = { availability_zone = "us-east-1b" }
}

override_data {
  target = module.sandbox.data.aws_subnet.egress_gateway_nlb[2]
  values = { availability_zone = "us-east-1c" }
}

override_data {
  target = module.sandbox.data.aws_subnet.restricted_egress_existing[0]
  values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1a" }
}

override_data {
  target = module.sandbox.data.aws_subnet.restricted_egress_existing[1]
  values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1b" }
}

override_data {
  target = module.sandbox.data.aws_subnet.restricted_egress_existing[2]
  values = { vpc_id = "vpc-0123456789abcdef0", availability_zone = "us-east-1c" }
}

run "computed_third_subnet_keeps_a_known_count" {
  command = plan
  module {
    source = "./tests/fixtures/loop-computed-subnet"
  }

  assert {
    condition     = module.sandbox.existing_private_subnet_count == 3
    error_message = "A third subnet ID that is unknown until apply must still plan as three subnets."
  }
}
