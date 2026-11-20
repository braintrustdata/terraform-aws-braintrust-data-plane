# Origin request policy was count-gated before v7.
moved {
  from = aws_cloudfront_origin_request_policy.all_viewer_with_forwarded_proto[0]
  to   = aws_cloudfront_origin_request_policy.all_viewer_with_forwarded_proto
}
