# Braintrust Data Plane - Internal

This example deploys a Braintrust data plane whose primary API endpoint is intended for private network access only. It does not create the standard public ingress path, so customers can expose the data plane through private DNS, VPN, Direct Connect, transit gateway, VPC peering, or another internal connectivity pattern.

Use this example when the Braintrust data plane should not require public ingress.

## Configure Terraform

* `provider.tf` should be modified to use your AWS account and region.
* `terraform.tf` should be modified to use the remote backend your company uses.
* `main.tf` should be modified for your organization, sizing, tags, and network ranges.
* Set `brainstore_license_key` from the Braintrust UI under Settings > Data Plane.
* Replace the `api_ecs_fqdn` placeholder with the DNS name users will configure in Braintrust.
* Replace the `api_ecs_authorized_cidr_blocks` placeholder with the private networks allowed to reach the internal endpoint.

## DNS

By default, this example lets the module create the ACM certificate, DNS validation records, and endpoint alias record. The module derives the Route53 hosted zone from `api_ecs_fqdn` by removing the first DNS label. For example, `braintrust-api.example.com` uses the `example.com` hosted zone that should be in this AWS account.

If you need to use a pre-provisioned ACM certificate, ACM Private CA, DNS validation in another account, a private hosted zone, split-horizon DNS, or corporate DNS outside Route53, use one of the commented alternatives in `main.tf`.

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

After applying, use the `api_url` output as the API URL in the Braintrust dashboard.

## Notes

The endpoint is internal, but it is still protected by the load balancer access rules. Make sure `api_ecs_authorized_cidr_blocks` covers the private networks your users or clients will connect from.
