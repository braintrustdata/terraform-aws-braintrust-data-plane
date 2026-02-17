# tflint-ignore-file: terraform_module_pinned_source

# Your existing Braintrust data plane module instantiation.
# See examples/braintrust-data-plane for full configuration options.
module "braintrust-data-plane" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # ... your eixsting configuration ...
}

###############################################################################
# CloudFront Standard Logging (V2) to S3
#
# This configuration enables CloudFront standard access logging using AWS's
# V2 logging API. Logs are delivered to an S3 bucket in Parquet format in this example.
#
# You might consider putting this in a separate file to keep your main.tf clean.
#
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#with-v2-logging-to-s3
###############################################################################

# Log delivery source - references the Braintrust CloudFront distribution from your existing module
resource "aws_cloudwatch_log_delivery_source" "cloudfront" {
  name         = "braintrust-cloudfront-logs"
  log_type     = "ACCESS_LOGS"
  resource_arn = module.braintrust-data-plane.cloudfront_distribution_arn
}

# Log delivery destination - the S3 bucket you want to use for logging
resource "aws_cloudwatch_log_delivery_destination" "s3" {
  name          = "braintrust-cloudfront-logs-s3"
  output_format = "parquet"

  delivery_destination_configuration {
    destination_resource_arn = "<YOUR_S3_BUCKET_ARN>"
  }
}

# Log delivery - connects the source to the destination
resource "aws_cloudwatch_log_delivery" "cloudfront_to_s3" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudfront.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.s3.arn

  s3_delivery_configuration {
    suffix_path = "/braintrust/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
  }
}
