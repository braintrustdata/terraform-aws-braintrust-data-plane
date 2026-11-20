# Generation profile for modules/remote-support. See iam.tftest.hcl.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_data "aws_partition" {
    defaults = { partition = "aws-manifest", dns_suffix = "amazonaws.com" }
  }

  # Apply mode materializes concrete values, and the provider validates many of
  # them as ARNs. These defaults only keep that validation happy. The roles get
  # their own through override_resource.
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws-manifest:iam::123456789012:role/manifest-unoverridden" }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = { arn = "arn:aws-manifest:iam::123456789012:instance-profile/manifest-unoverridden" }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

override_resource {
  target = aws_iam_role.braintrust_support[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-remote_support.braintrust_support"
    id  = "manifest-remote_support.braintrust_support"
  }
}

override_resource {
  target = aws_iam_role.bastion[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-remote_support.bastion"
    id  = "manifest-remote_support.bastion"
  }
}

override_resource {
  target = aws_iam_instance_profile.bastion[0]
  values = { arn = "arn:aws-manifest:iam::123456789012:instance-profile/manifest-remote_support-bastion" }
}

# The EC2 Instance Connect policy names these two by id.
override_resource {
  target = aws_instance.bastion[0]
  values = { id = "manifest-remote_support-bastion" }
}

override_resource {
  target = aws_ec2_instance_connect_endpoint.endpoint[0]
  values = { id = "manifest-remote_support-endpoint" }
}

run "remote_support_logs_and_shell" {
  command = apply
  module { source = "./modules/remote-support" }

  variables {
    deployment_name                        = "bt-manifest"
    vpc_id                                 = "vpc-12345678"
    public_subnet_ids                      = ["subnet-11111111"]
    private_subnet_ids                     = ["subnet-22222222", "subnet-33333333"]
    database_host                          = "db.example.internal"
    database_secret_arn                    = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:database"
    redis_url_secret_arn                   = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:redis"
    redis_url_secret_version_id            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    kms_key_arn                            = "arn:aws-manifest:kms:us-east-1:123456789012:key/test"
    enable_braintrust_support_logs_access  = true
    enable_braintrust_support_shell_access = true
  }
}
