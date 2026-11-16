# API ALB listener and CloudFront origin transitions

This module change separates the public CloudFront path from customer HTTPS access to the internal API ALB. Review the plan against the listener that is already in your state before applying.

## What changes when adopting this layout

- The existing `module.api_ecs[0].aws_lb_listener.api_ecs_http` state address moves to `module.api_ecs[0].aws_lb_listener.api_ecs_http[0]`. Terraform's `moved` block preserves the live listener.
- Existing public HTTP deployments keep their attached, HTTP-only API VPC origin. A deployment with a legacy HTTPS listener uses a new HTTP-only API VPC origin on ALB port 80; its old HTTPS origin remains in state, unattached, because CloudFront cannot update an origin while a distribution uses it. The distribution keeps its public hostname during this upgrade.
- A deployment whose existing listener is HTTPS:443 also gains a separate HTTP:80 listener and its API, ingest, and background path rules. The HTTPS listener and certificate remain untouched. A deployment whose listener is HTTP:80 retains it.
- A private deployment keeps port 80 closed in the ALB security group. Its customer HTTPS:443 and internal callback HTTP:8000 paths remain available.

New private installations and existing public HTTP deployments use the same layout: the original listener stays on HTTP:80 and a separate customer listener serves HTTPS:443. Supplying the ALB hostname and certificate creates the HTTPS listener in either public or private mode.

Legacy HTTPS deployments need one additional VPC origin, which counts against the account's [CloudFront VPC origin quota](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-limits.html). Check available quota before upgrading accounts with many such distributions.

The listener state move, and for legacy HTTPS deployments the CloudFront origin attachment, make a rollback to the previous listener layout unsafe: older code can plan listener replacement or an in-use VPC origin update. Review any rollback plan before applying it.

## Stage private access from a public HTTP deployment

First update the module with your current public configuration and inspect the plan. The existing listener should remain HTTP:80. Then set:

```hcl
enable_private_dataplane           = false
braintrust_api_alb_custom_domain   = "api.example.internal"
braintrust_api_alb_certificate_arn = "arn:aws:acm:REGION:ACCOUNT:certificate/CERTIFICATE_ID"
braintrust_api_authorized_cidr_blocks = ["10.20.0.0/16"]
```

The ALB hostname and certificate add a separate HTTPS:443 listener and complete direct API, ingest, background, Gateway, and enabled Loop routes. This requires ECS API and an enabled private AI Gateway. The CloudFront distribution and HTTP:80 listener remain the public request path. `api_url` still names CloudFront; `private_api_url` names the customer HTTPS hostname for testing.

Configure your private DNS and client network path, then test the exact customer hostname, certificate trust, API requests, `/v1/proxy`, and, if enabled, `/loop/runtime`. Only the authorized customer CIDRs or security groups may reach port 443. CloudFront reaches port 80 through its managed prefix list; API and Brainstore service security groups may also reach port 80. Port 8000 remains private-mode-only.

The ALB certificate may be issued by a private CA trusted by your direct clients. CloudFront continues to use HTTP inside its VPC origin path and does not validate that certificate. CloudFront [requires a publicly trusted CA for an HTTPS origin](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html).

## Cut over and return

After the direct path works, set `enable_private_dataplane = true` while keeping the hostname and certificate. Coordinate the client and Braintrust API URL cutover. This removes CloudFront and opens the internal HTTP:8000 callback path. The ALB HTTP:80 listener remains, with CloudFront admission removed.

Customers who do not need to test the private path can still use two applies: first provide the ALB hostname, certificate, and authorized client networks while staying in public mode; then set `enable_private_dataplane = true`. The first apply provisions HTTPS:443 without changing the public HTTP:80 path, and the second cuts over without a testing gate. A single apply that changes the mode and adds TLS inputs also plans, but Terraform cannot make CloudFront removal and private listener creation atomic; use two applies for a predictable existing-deployment cutover. A new private installation uses `enable_private_dataplane = true` and the TLS inputs in its first apply, with no migration flag.

To return to public mode, set `enable_private_dataplane = false` and keep the hostname and certificate until public access is healthy. CloudFront is recreated against HTTP:80; HTTPS:443 stays available. The new CloudFront distribution can have a different AWS hostname, so review DNS and `api_url` before directing clients back to it. Retest API, proxy, Loop, and callbacks.

After public access is healthy, remove the ALB hostname and certificate to delete the separate HTTPS:443 listener. If a customer-owned NLB targets this ALB on port 443, first deregister the ALB target and wait until draining finishes. AWS requires an ALB target group's port to match an ALB listener and does not permit removing the listener while that target is registered. The module cannot coordinate a customer-owned NLB's lifecycle.

## Existing private or public HTTPS listener

For a deployment whose existing `api_ecs_http` listener is HTTPS:443, set `legacy_api_https_listener = true` and **keep the ALB hostname and certificate during the module update**. This is the only migration-specific listener setting. The update leaves it at 443 and adds HTTP:80 independently. Public mode uses the new HTTP path; private mode keeps it closed by security group. Confirm the original listener protocol in Terraform state before setting this flag. Leave it false for existing public HTTP deployments and new installations.

If that deployment is already public, the same `legacy_api_https_listener = true` setting preserves its existing 443 listener while CloudFront moves to HTTP:80. Do not use this flag for an original HTTP:80 listener: that would request the unsafe in-place protocol change.

To move an existing private deployment to public mode, first set `enable_private_dataplane = false` and `legacy_api_https_listener = true`, retaining the hostname and certificate. Apply and verify the public CloudFront path. If a customer-owned NLB targets port 443, deregister the ALB and wait for draining. Then, in a later apply, remove the ALB hostname and certificate and set `retire_legacy_api_https_listener = true`, keeping the legacy setting. Terraform deletes the old HTTPS listener; the separate HTTP:80 listener and CloudFront route stay in place. Keep both settings in later applies. For another private staging cycle, supply a hostname and certificate while keeping those settings.

`retire_legacy_api_https_listener` is only for a deployment whose original listener was HTTPS:443. Setting it on an original HTTP:80 deployment would attempt to replace the active port 80 listener and is unsupported. Review `terraform state show` and the plan before using it. Do not combine the first retirement apply with a new private cutover.

If an external NLB still has the ALB registered on 443, its owner must deregister and drain it before the retirement apply. This external prerequisite cannot be made atomic with the module's Terraform apply. Do not remove the 443 listener or its certificate in the same apply that switches from private to public mode.
