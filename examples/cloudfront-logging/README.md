# CloudFront Logging Example

This example shows how to enable CloudFront standard access logging for your Braintrust data plane deployment.

## Overview

There are many ways to configure CloudFront logging and each company may have their own requirements. Rather than exposing many logging variables directly in the Braintrust module, you can configure CloudFront logging independently to meet your own needs by referencing the `cloudfront_distribution_arn` output from the module.

## Usage

Add the logging resources from `main.tf` alongside your existing Braintrust data plane module instantiation. The key integration point is the `cloudfront_distribution_arn` output:

```hcl
resource "aws_cloudwatch_log_delivery_source" "cloudfront" {
  name         = "braintrust-cloudfront-logs"
  log_type     = "ACCESS_LOGS"
  resource_arn = module.braintrust-data-plane.cloudfront_distribution_arn
}
```

## Customization

You can customize this example to fit your needs:

- **Output format**: Change `output_format` to `"json"`, `"plain"`, `"w3c"`, or `"raw"` instead of `"parquet"`
- **S3 path structure**: Modify the `suffix_path` in `s3_delivery_configuration` to organize logs differently
- **Bucket configuration**: Add lifecycle rules, encryption, or replication to the S3 bucket as needed
- **Alternative destinations**: Logs can also be delivered to CloudWatch Logs or Firehose instead of S3

## References

- [AWS CloudFront V2 Logging Documentation](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/standard-logging.html)
- [Terraform aws_cloudwatch_log_delivery_source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_source)
- [Terraform aws_cloudwatch_log_delivery_destination](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery_destination)
- [Terraform aws_cloudwatch_log_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_delivery)
