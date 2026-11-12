# Private data plane example

This example deploys a production-sized data plane through an internal HTTPS API ALB instead of CloudFront.

> [!WARNING]
> Coordinate a cutover before a change between public and private mode.
> Each transition causes an outage, deletes or recreates CloudFront, and changes the client endpoint.

## Before you start

- An API hostname under a domain that you control.
- A certificate in ACM in the deployment account and region that covers the hostname. All clients must trust its issuer.
- Client network connectivity to the main VPC, plus DNS that resolves the hostname to the internal ALB once it has been provisioned by this module.
- Outbound access for Braintrust Control Plane, AWS services, model providers, and other dependencies.
- VPC CIDRs that fit your network design.

The module does not create the certificate, client DNS records, or client network connectivity like VPN, VPC Peering, Transit Gateway or PrivateLink.
The optional sections below cover [certificate validation](#certificates-and-dns) and [existing VPCs](#existing-vpcs).

## Configure Terraform

1. Copy this directory into your own repository.
2. Edit `provider.tf` for your AWS account, region, and credential profile.
3. Edit `terraform.tf` for your remote backend.
4. Edit `main.tf` for your organization, capacity, and VPC CIDRs.
5. Set `braintrust_api_alb_custom_domain` to your API hostname.
6. Set `braintrust_api_alb_certificate_arn` to the validated ACM certificate ARN.
7. Configure `braintrust_api_authorized_cidr_blocks` or `braintrust_api_authorized_security_groups` for HTTPS client access on port 443.
8. Supply `brainstore_license_key` through your deployment environment or secret manager.

The license key is available under Settings > Data Plane in the Braintrust UI.
The [standard example](../braintrust-data-plane/README.md#configure-terraform) describes Secrets Manager configuration. `TF_VAR_brainstore_license_key` is an alternative.

The example sets all required mode flags:

```hcl
enable_private_dataplane = true
enable_ecs_api           = true
create_ai_gateway        = true
enable_ai_gateway        = true
```

## Deploy and configure DNS

1. For a new AWS account, run `scripts/create-service-linked-roles.sh` from the module repository.
2. In the copied directory, run `terraform init`.
3. Run `terraform plan`.
4. Review the resource capacity and network changes.
5. Run `terraform apply`.
6. Establish client network connectivity to the main VPC.
7. Find the internal ALB named `<deployment_name>-api-ecs` in the AWS console.
8. Create a DNS record for your API hostname that points to the ALB DNS name.
9. Verify DNS resolution from each client network.
10. Verify HTTPS access from each client network.

The default ALB name is `braintrust-api-ecs`.
Route 53 supports an alias A record. Other providers can use a CNAME below the zone apex.
Public or private DNS works. A public record for an internal ALB still resolves to private IP addresses.
Security group admission alone does not establish network connectivity.

## Configure your organization

1. Run `terraform output -raw api_url`.
2. In the Braintrust UI, open Settings > Data Plane for your organization.
3. Click Edit beside API URL.
4. Set API URL to the Terraform output value, such as `https://braintrust-api.example.com`.
5. Select **Data plane is on a private network**.
6. Click Save.
7. Verify that the endpoint checks succeed from a browser with network access to the ALB.
8. Configure your SDKs with the same API URL.
9. If quarantine is enabled, verify quarantine function calls.
10. If Loop is enabled, verify Loop streams and terminal sessions.

## Private request paths

| Traffic | Private path |
| --- | --- |
| Customer API requests | HTTPS hostname → API ALB → API, ingest, or background service |
| Customer LLM requests | HTTPS hostname → API ALB → gateway tasks |
| Loop HTTP, SSE, and terminal WebSockets | HTTPS hostname → API ALB → Loop tasks |
| Service API callbacks | ALB AWS hostname on HTTP port 8000 → API services |
| Quarantine API and LLM requests, when enabled | Interface endpoint → internal NLB → API ALB → API services or Gateway tasks |

## Private ingress responsibilities

**Your responsibility is to deliver client traffic to the internal API ALB on HTTPS port 443 using your configured API hostname.**
Choose the connectivity that fits your environment, such as Client VPN, existing routed connectivity, VPC peering, Transit Gateway, or PrivateLink. Provide DNS for that path, a matching ACM certificate, client trust in its issuer, and the source CIDRs or security group IDs to authorize through the module's inputs. Clients should use `https://<braintrust_api_alb_custom_domain>` so the TLS server name and HTTP Host match the configured hostname.

**Braintrust's module and services are responsible for handling requests once they reach the ALB through that configured ingress.**
The module attaches `braintrust_api_alb_certificate_arn` to the HTTPS 443 listener, creates ALB ingress rules from your authorization inputs, and routes requests to the appropriate API, ingest, background, AI Gateway, or enabled Loop service. Application authentication and authorization still apply; network access alone does not grant access to data.

The client access network is separate from the module-managed quarantine PrivateLink path described above.

## Network and architecture details

## Certificates and DNS

The API certificate must reside in ACM in the deployment account and region and cover `braintrust_api_alb_custom_domain`.
ACM-issued, imported, and private CA certificates work if every client trusts the issuer.

ACM public certificates require domain ownership validation.
For DNS validation, the validation CNAME must resolve through public DNS.
The API hostname does not require a public address record for validation.
The [ACM documentation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html) describes DNS validation.

Every client network must resolve the API hostname to the internal ALB and have network connectivity to it.
Public DNS avoids separate private DNS configuration. Private DNS works if all clients can resolve the hostname.
The module does not create client connectivity through VPN, PrivateLink, VPC peering, or a transit gateway.
The quarantine PrivateLink connection is separate from client access.

## Existing VPCs

Main and quarantine VPC choices are independent in public and private modes.
The module creates service security groups and applicable quarantine PrivateLink resources in supplied VPCs.
It does not change their routes or DNS controls.

An existing main VPC requires:

- Three private subnets in distinct availability zones.
- At least one public subnet.
- An internet gateway and NAT gateway with routes for the private subnets.

### Main VPC configuration

```hcl
module "braintrust-data-plane" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"

  # ... your existing configuration ...

  # Use existing VPC
  create_vpc = false
  existing_vpc_id                        = "vpc-xxxxxxxxx"
  existing_private_subnet_1_id           = "subnet-xxxxxxxxx"
  existing_private_subnet_2_id           = "subnet-yyyyyyyyy"
  existing_private_subnet_3_id           = "subnet-zzzzzzzzz"
  existing_public_subnet_1_id            = "subnet-aaaaaaaaa"
}
```

### Quarantine VPC configuration

An existing quarantine VPC requires its VPC ID and three private subnet IDs:

```hcl
existing_quarantine_vpc_id              = "vpc-22222222222222222"
existing_quarantine_private_subnet_1_id = "subnet-44444444444444444"
existing_quarantine_private_subnet_2_id = "subnet-55555555555555555"
existing_quarantine_private_subnet_3_id = "subnet-66666666666666666"
```

## Optional quarantine API access

Choose quarantine connectivity before applying.
Enabling the quarantine VPC does not automatically enable PrivateLink access to the API or AI Gateway.

| Input | Default | Private mode | Public mode |
| --- | --- | --- | --- |
| `create_quarantine_api_access` | `false` | Enables quarantine API and AI Gateway access through the API ALB on HTTP port 8000. Requires `enable_quarantine_vpc = true`. | Ignored. |
| `use_private_gateway_quarantine_proxy` | `false` | Ignored. | Enables quarantine LLM proxy access through the Gateway ALB when quarantine and `create_ai_gateway` are enabled and `use_global_ai_gateway_origin = false`. |

For quarantine functions that need API callbacks or the data plane's AI Gateway in private mode, set:

```hcl
enable_quarantine_vpc        = true
create_quarantine_api_access = true
```

With access enabled, quarantine uses one base URL from `quarantine_api_url`.
The backend uses that URL for API requests and appends `/v1/proxy` for Gateway requests.
The internal API listener also includes Loop routes when Loop is enabled.
The endpoint accepts only the quarantine Lambda security group and the NLB reaches only the API ALB on TCP port 8000.
User authentication and organization permissions remain required.

When switching from public to private mode, set `create_quarantine_api_access = true` before applying if quarantine functions need this access. Leaving only `use_private_gateway_quarantine_proxy = true` does not preserve it: that flag is ignored in private mode, and Terraform removes quarantine PrivateLink when `create_quarantine_api_access` is false.
Conversely, public mode ignores `create_quarantine_api_access`; select `use_private_gateway_quarantine_proxy` for quarantine LLM PrivateLink in that mode. The public path provides Gateway access, not the private API callback path.
