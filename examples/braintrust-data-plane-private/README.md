This is an example of a private-only Braintrust data plane deployment. It does
not create CloudFront, API Gateway, or Lambda service resources. The API ECS
service is the only API ingress path, and `custom_domain` is the HTTPS client
API URL to configure in the Braintrust dashboard. Internally we use the same
domain.

Create the DNS record outside the module, pointing `custom_domain` at the API
ECS ALB. Create an ACM certificate outside the module that covers
`custom_domain`, then pass it as `custom_certificate_arn`.

