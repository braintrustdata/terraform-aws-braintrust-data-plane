This is an example of a private-only Braintrust data plane deployment. It does
not create CloudFront, API Gateway, or Lambda service resources. The API ECS
service is the only API ingress path, and `custom_domain` is the client API URL
to configure in the Braintrust dashboard.

Create the DNS record outside the module, pointing `custom_domain` at the API
ECS ALB. By default, this example exposes the API ECS ALB over HTTP on port
8000. To enable HTTPS, also create an ACM certificate outside the module and set
`custom_certificate_arn`.
