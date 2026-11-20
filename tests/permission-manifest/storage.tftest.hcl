# Generation profile for modules/storage. See iam.tftest.hcl.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_data "aws_partition" {
    defaults = { partition = "aws-manifest", dns_suffix = "amazonaws.com" }
  }

  # Apply mode materializes concrete values, and the provider validates many of
  # them as ARNs. These defaults only keep that validation happy.
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws-manifest:s3:::manifest-unoverridden" }
  }
}

override_resource {
  target = aws_s3_bucket.brainstore[0]
  values = {
    arn = "arn:aws-manifest:s3:::manifest-storage-brainstore"
    id  = "manifest-storage-brainstore"
  }
}

override_resource {
  target = aws_s3_bucket.code_bundle_bucket
  values = {
    arn = "arn:aws-manifest:s3:::manifest-storage-code_bundle_bucket"
    id  = "manifest-storage-code_bundle_bucket"
  }
}

override_resource {
  target = aws_s3_bucket.lambda_responses_bucket
  values = {
    arn = "arn:aws-manifest:s3:::manifest-storage-lambda_responses_bucket"
    id  = "manifest-storage-lambda_responses_bucket"
  }
}

run "storage_bucket_policies" {
  command = apply
  module { source = "./modules/storage" }

  variables {
    deployment_name           = "bt-manifest"
    manage_s3_bucket_policies = true
  }
}
