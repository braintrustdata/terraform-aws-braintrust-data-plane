# Shared AWS mock defaults for plan-mode smoke tests.
# Loaded via: mock_provider "aws" { source = "./tests/mocks/aws" }

mock_data "aws_availability_zones" {
  defaults = {
    names = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}

mock_data "aws_caller_identity" {
  defaults = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:root"
    user_id    = "AIDAEXAMPLE"
  }
}

mock_data "aws_region" {
  defaults = {
    name   = "us-east-1"
    id     = "us-east-1"
    region = "us-east-1"
  }
}

mock_data "aws_secretsmanager_random_password" {
  defaults = {
    random_password = "mock-password-16"
  }
}

# Brainstore postconditions require local NVMe (total_instance_storage != null).
mock_data "aws_ec2_instance_type" {
  defaults = {
    total_instance_storage  = 950
    supported_architectures = ["arm64"]
  }
}

mock_data "aws_ami" {
  defaults = {
    id = "ami-0123456789abcdef0"
  }
}

mock_data "aws_ec2_managed_prefix_list" {
  defaults = {
    id = "pl-0123456789abcdef0"
  }
}

mock_data "aws_iam_policy_document" {
  defaults = {
    json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"sts:AssumeRole\",\"Principal\":{\"Service\":\"ecs-tasks.amazonaws.com\"}}]}"
  }
}
