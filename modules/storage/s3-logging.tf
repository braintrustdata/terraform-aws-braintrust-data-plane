resource "aws_s3_bucket_logging" "access_logs" {
  for_each = local.s3_server_access_logging_enabled ? local.s3_server_access_logging_buckets : {}

  bucket        = each.value
  target_bucket = var.s3_server_access_logging_bucket
  target_prefix = "${local.s3_server_access_logging_prefix}${each.key}/"

  target_object_key_format {
    partitioned_prefix {
      partition_date_source = "EventTime"
    }
  }
}
