mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name       = "bt-test"
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
  flow_log = {
    enabled = true
  }
}

run "managed_by_default" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  assert {
    condition = (
      var.manage_s3_public_access_block &&
      length(aws_s3_bucket_public_access_block.flow_log) == 1 &&
      aws_s3_bucket_public_access_block.flow_log[0].block_public_acls &&
      aws_s3_bucket_public_access_block.flow_log[0].block_public_policy &&
      aws_s3_bucket_public_access_block.flow_log[0].ignore_public_acls &&
      aws_s3_bucket_public_access_block.flow_log[0].restrict_public_buckets
    )
    error_message = "Manage all four protections on the flow-log bucket by default."
  }
}

run "new_deployment_opt_out" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    manage_s3_public_access_block = false
  }

  assert {
    condition = (
      length(aws_s3_bucket_public_access_block.flow_log) == 0 &&
      length(aws_s3_bucket.flow_log) == 1 &&
      length(aws_s3_bucket_policy.flow_log) == 1 &&
      length(aws_s3_bucket_ownership_controls.flow_log) == 1 &&
      length(aws_s3_bucket_server_side_encryption_configuration.flow_log) == 1 &&
      length(aws_flow_log.vpc) == 1
    )
    error_message = "Opt-out must skip only the flow-log public access block."
  }
}

run "caller_destination_stays_unmanaged" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    flow_log = {
      enabled         = true
      destination_arn = "arn:aws:s3:::customer-flow-logs"
    }
  }

  assert {
    condition = (
      length(aws_s3_bucket.flow_log) == 0 &&
      length(aws_s3_bucket_public_access_block.flow_log) == 0
    )
    error_message = "Do not manage a caller-provided flow-log bucket."
  }
}
