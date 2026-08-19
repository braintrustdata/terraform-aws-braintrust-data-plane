# Origin request policy is always created so enable_ecs_api rollback does not
# delete it in the same apply that detaches it from the CloudFront distribution.
moved {
  from = aws_cloudfront_origin_request_policy.all_viewer_with_forwarded_proto[0]
  to   = aws_cloudfront_origin_request_policy.all_viewer_with_forwarded_proto
}
