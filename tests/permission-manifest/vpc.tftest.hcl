# Generation profiles for modules/vpc. See iam.tftest.hcl.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_data "aws_partition" {
    defaults = { partition = "aws-manifest", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }

  # Apply mode materializes concrete values, and the provider validates many of
  # them as ARNs. These defaults only keep that validation happy. The flow log
  # role, log group and bucket get their own through override_resource.
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws-manifest:iam::123456789012:role/manifest-unoverridden" }
  }
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:manifest-unoverridden" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws-manifest:s3:::manifest-unoverridden" }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

override_resource {
  target = aws_iam_role.flow_log[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-vpc.flow_log"
    id  = "manifest-vpc.flow_log"
  }
}

override_resource {
  target = aws_cloudwatch_log_group.flow_log[0]
  values = { arn = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:manifest-vpc-flow_log" }
}

override_resource {
  target = aws_s3_bucket.flow_log[0]
  values = {
    arn = "arn:aws-manifest:s3:::manifest-vpc-flow_log"
    id  = "manifest-vpc-flow_log"
  }
}

override_data {
  target = data.aws_iam_policy_document.flow_log_assume_role
  values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.flow_log_assume_role\"}" }
}

override_data {
  target = data.aws_iam_policy_document.flow_log
  values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.flow_log\"}" }
}

override_data {
  target = data.aws_iam_policy_document.flow_log_bucket
  values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.flow_log_bucket\"}" }
}

override_data {
  target = data.aws_iam_policy_document.s3_vpc_endpoint
  values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.s3_vpc_endpoint\"}" }
}

# Every run applies the same VPC and differs only in its flow log and S3 endpoint inputs.
variables {
  deployment_name       = "bt-manifest"
  vpc_name              = "main"
  vpc_cidr              = "10.175.0.0/21"
  public_subnet_1_cidr  = "10.175.0.0/24"
  public_subnet_1_az    = "us-east-1a"
  private_subnet_1_cidr = "10.175.1.0/24"
  private_subnet_1_az   = "us-east-1a"
  private_subnet_2_cidr = "10.175.2.0/24"
  private_subnet_2_az   = "us-east-1b"
  private_subnet_3_cidr = "10.175.3.0/24"
  private_subnet_3_az   = "us-east-1c"
}

run "vpc_flow_logs_to_cloud_watch" {
  command = apply
  module { source = "./modules/vpc" }

  variables {
    flow_log = {
      enabled          = true
      destination_type = "cloud-watch-logs"
    }
  }
}

run "vpc_flow_logs_to_s3" {
  command = apply
  module { source = "./modules/vpc" }

  variables {
    flow_log = {
      enabled          = true
      destination_type = "s3"
    }
  }
}

run "vpc_s3_endpoint_restricted" {
  command = apply
  module { source = "./modules/vpc" }

  variables {
    flow_log                             = { enabled = false }
    s3_vpc_endpoint_resource_org_ids     = ["o-manifest00"]
    s3_vpc_endpoint_resource_account_ids = ["210987654321"]
  }
}
