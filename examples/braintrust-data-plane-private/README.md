# Private data plane example

This example deploys a production-sized private Braintrust data plane.
It follows the file layout and capacity configuration of the [standard production example](../braintrust-data-plane/).
The API ALB replaces CloudFront as the client endpoint.

## Requirements

Private mode requires these settings:

- `enable_private_dataplane = true`.
- `enable_ecs_api = true`.
- `create_ai_gateway = true`.
- `enable_ai_gateway = true`.

Private mode supports module-managed VPCs, customer-supplied VPCs, and a mixture of both.

### Existing VPCs

For an existing main VPC, set `create_vpc = false` and supply these inputs:

- `existing_vpc_id`.
- `existing_private_subnet_1_id`, `existing_private_subnet_2_id`, and `existing_private_subnet_3_id`.
- `existing_public_subnet_1_id`.

For an existing quarantine VPC, supply these inputs:

- `existing_quarantine_vpc_id`.
- `existing_quarantine_private_subnet_1_id`, `existing_quarantine_private_subnet_2_id`, and `existing_quarantine_private_subnet_3_id`.

The main and quarantine VPC choices are independent.
With quarantine enabled, PrivateLink requires three distinct private subnets per VPC in matching availability zones.
Both VPCs must reside in the deployment account and region.
The module validates subnet membership and availability zone coverage.

The module creates service security groups and the quarantine PrivateLink resources in the supplied VPCs.
The caller controls routes, network ACLs, DNS, and access to AWS services and model providers.
The module does not change routes or DNS controls in supplied VPCs.
Quarantine DNS must resolve the endpoint hostname, and network ACLs must permit the connection and return traffic.

Private mode controls client ingress.
It does not remove service egress requirements.
The [existing VPC configuration](../../README.md#using-an-existing-vpc) describes the standard network requirements.

### Certificate

The endpoint certificate must reside in AWS Certificate Manager (ACM), in the same AWS account and region as the API ALB.
The certificate must cover the hostname in `braintrust_api_alb_custom_domain`.
`braintrust_api_alb_certificate_arn` accepts the ARN of that certificate.

For ease of use, we recommend a publicly trusted certificate that ACM issues, however this is not required.
An imported certificate or a certificate from a private certificate authority also works if it resides in ACM.
Every browser, SDK, and other client must trust the certificate issuer.

ACM public certificates require domain ownership validation.
With DNS validation, the validation CNAME must resolve through public DNS.
The API hostname does not require a public address record for certificate validation.
See [ACM DNS validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html) for details.

### DNS and network access

The endpoint hostname must resolve to the internal API ALB from every client network.
Public DNS resolution is optional but recommended because it avoids a separate private DNS configuration for clients.
A public DNS record for an internal ALB still directs clients to private IP addresses.
It does not provide public network access to the ALB.
Private DNS also works if every client network can resolve the hostname.

The customer supplies DNS and network connectivity to the API ALB.
The module does not create a customer VPN, PrivateLink endpoint, VPC peering connection, or transit gateway attachment.
The API authorization inputs admit client traffic on HTTPS port 443.
Security group admission alone does not establish network connectivity.

## Prepare the certificate and network

1. Select an API hostname under a domain that you control, such as `braintrust-api.example.com`.
2. Request or import its certificate in ACM in the deployment account and region.
3. Complete any certificate validation before the data plane deployment.
4. Select nonoverlapping VPC CIDR for the primary VPC and the client networks, if utilizing VPC connections like VPC Peering, Transit Gateway, etc.
5. Plan client connectivity to the main VPC.

The default Loop sandbox CIDR is `10.255.0.0/16` when Loop is enabled.
All VPC CIDRs must fit the customer network design.

## Configure Terraform

1. Copy this directory into your own repository.
2. Edit `provider.tf` for your AWS account, region, and credential profile.
3. Edit `terraform.tf` for your remote backend.
4. Set the module source in `main.tf` to a release or branch that includes private mode support.
5. Edit `main.tf` for your organization, capacity, and VPC CIDRs.
6. Set `braintrust_api_alb_custom_domain` to the selected API hostname.
7. Set `braintrust_api_alb_certificate_arn` to the ACM certificate ARN.
8. Configure `braintrust_api_authorized_cidr_blocks` or `braintrust_api_authorized_security_groups` for your clients.
9. Supply `brainstore_license_key` through your deployment environment or secret manager.

The Braintrust UI supplies the license key under Settings > Data Plane.
The example uses the same `brainstore_license_key` variable as the standard production example.
The [standard production example](../braintrust-data-plane/README.md#configure-terraform) describes the Secrets Manager option.
`TF_VAR_brainstore_license_key` is an alternative.

## Deploy the data plane

1. For a new AWS account, run `scripts/create-service-linked-roles.sh` from the module repository.
2. In the copied example directory, run `terraform init`.
3. Run `terraform plan`.
4. Review the resource capacity and network changes.
5. Run `terraform apply`.
6. Establish client network connectivity to the deployed VPC.
7. Find the internal API ALB in the AWS console or Terraform output.
8. Create a DNS record for your API hostname that points to the ALB DNS name.
9. Verify hostname resolution from each required client network.
10. Verify HTTPS access from each required client network.

The DNS record can use a public or private zone.
Route 53 supports an alias A record for the ALB.
Other DNS providers can use a CNAME for a hostname below the zone apex.
The example does not create the certificate, DNS records, or client network connection.

The API ALB name follows `<deployment_name>-api-ecs`.
The example uses `braintrust-api-ecs` unless you change `deployment_name`.

## Configure your organization

1. Run `terraform output -raw api_url`.
2. In the Braintrust UI, open Settings > Data Plane for your organization.
3. Click Edit beside API URL.
4. Set API URL to the Terraform output value.
5. Check Data plane is on a private network
6. Click Save.
7. Verify that the endpoint checks succeed from a browser with network access to the ALB.
8. Configure your SDKs with the same API URL.
9. Verify quarantine function calls.
10. If Loop is enabled, verify Loop streams and terminal sessions.

Example output:

```text
https://braintrust-api.example.com
```

## Private request paths

| Traffic | Private path |
| --- | --- |
| Customer API requests | Customer HTTPS hostname → API ALB → API, ingest, or background service |
| Customer LLM requests | Customer HTTPS hostname → API ALB → private AI gateway tasks |
| Loop HTTP, SSE, and terminal WebSockets | Customer HTTPS hostname → API ALB → Loop tasks |
| Brainstore, gateway, and Loop API callbacks | ALB AWS hostname on HTTP port 8000 → API services |
| Quarantine LLM requests | Quarantine interface endpoint → internal NLB → private gateway ALB |

Service callbacks use the ALB AWS hostname on HTTP port 8000 through explicit service security groups.
They do not depend on the customer certificate or endpoint DNS record.
Application authentication still applies.

Both listeners route `/v1/proxy` and `/v1/proxy/*` directly to gateway tasks.
Both listeners route `/loop/runtime` and `/loop/runtime/*` directly to Loop tasks when Loop is enabled.
These routes accept all HTTP methods and support WebSocket upgrades and SSE.
They take priority over the API service routes and preserve each request path.
Loop model requests use the private AI gateway directly.

Private mode automatically creates the quarantine PrivateLink path when quarantine is enabled.
`use_private_gateway_quarantine_proxy` can retain its default value.
This path uses HTTP port 80 and incurs interface endpoint and NLB charges.

## Other behavior

Private mode rejects the hosted gateway settings `use_global_ai_proxy = true` and `use_global_ai_gateway_origin = true`.
It also rejects an explicit `quarantine_proxy_url` override.
`use_private_ai_gateway_origin` has no effect because CloudFront is absent.

`api_url` supplies the customer HTTPS URL.
CloudFront outputs are null in private mode.
`whitelisted_origins` controls API CORS admission for additional web application origins.
CORS admission does not establish network connectivity.

Private mode changes ingress only.
Outbound connectivity remains necessary for configured model providers and other external dependencies.

## Mode transitions

Each transition between public and private mode causes an outage.
The transition deletes or recreates CloudFront and changes the client endpoint.
The endpoint hostname, DNS configuration, and client network access require a coordinated cutover.
