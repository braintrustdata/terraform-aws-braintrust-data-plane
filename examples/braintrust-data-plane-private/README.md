This is an example of a private-only Braintrust data plane deployment. It does
not create CloudFront, API Gateway, or Lambda service resources. The API ECS
service is the only API ingress path, and the internal API ECS ALB is the API
URL to configure in the Braintrust dashboard.

By default, this example lets the module create an ACM certificate, Route53 DNS
validation records, and a Route53 alias record for the internal ALB. The hosted
zone is derived from `api_ecs_fqdn` by removing the first DNS label, so
`braintrust-api.internal.example.com` uses the `internal.example.com` hosted
zone.

To manage the certificate or DNS outside this module, see the commented
alternatives in `main.tf`.
