# Migrating from v7 to v8: API ALB listeners and CloudFront origin

This migration separates the public CloudFront path from customer HTTPS access to the internal API ALB. Upgrade one major version at a time. Review the plan against the listener that is already in your state before applying.

## What changes on upgrade

- The existing `module.api_ecs[0].aws_lb_listener.api_ecs_http` state address moves to `module.api_ecs[0].aws_lb_listener.api_ecs_http[0]`. Terraform's `moved` block preserves the live listener.
- CloudFront attaches a new, HTTP-only API VPC origin on ALB port 80. The old VPC origin remains in state, unattached, because CloudFront cannot update an origin while a distribution uses it. The distribution keeps its public hostname during this upgrade.
- A deployment whose existing listener is HTTPS:443 also gains a separate HTTP:80 listener and its API, ingest, and background path rules. The HTTPS listener and certificate remain untouched. A deployment whose listener is HTTP:80 retains it.
- A private deployment keeps port 80 closed in the ALB security group. Its customer HTTPS:443 and internal callback HTTP:8000 paths remain available.

The additional VPC origin counts against the account's [CloudFront VPC origin quota](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-limits.html). Check available quota before upgrading accounts with many distributions.

The listener state move and CloudFront origin attachment make a downgrade to v7 unsafe: v7 can plan listener replacement or an in-use VPC origin update. Do not roll back the module code after applying v8 without a reviewed migration plan.

## Stage private access from a public HTTP deployment

First upgrade to v8 with your current public configuration and inspect the plan. The existing listener should remain HTTP:80. Then set:

```hcl
enable_private_dataplane           = false
prepare_private_dataplane          = true
braintrust_api_alb_custom_domain   = "api.example.internal"
braintrust_api_alb_certificate_arn = "arn:aws:acm:REGION:ACCOUNT:certificate/CERTIFICATE_ID"
braintrust_api_authorized_cidr_blocks = ["10.20.0.0/16"]
```

`prepare_private_dataplane` requires ECS API and an enabled private AI Gateway. It adds a separate HTTPS:443 listener and complete direct API, ingest, background, Gateway, and enabled Loop routes. The CloudFront distribution and HTTP:80 listener remain the public request path. `api_url` still names CloudFront; `private_api_url` names the customer HTTPS hostname for testing.

Configure your private DNS and client network path, then test the exact customer hostname, certificate trust, API requests, `/v1/proxy`, and, if enabled, `/loop/runtime`. Only the authorized customer CIDRs or security groups may reach port 443. CloudFront reaches port 80 through its managed prefix list; API and Brainstore service security groups may also reach port 80. Port 8000 remains private-mode-only.

The ALB certificate may be issued by a private CA trusted by your direct clients. CloudFront continues to use HTTP inside its VPC origin path and does not validate that certificate. CloudFront [requires a publicly trusted CA for an HTTPS origin](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html).

## Cut over and return

After the direct path works, set `enable_private_dataplane = true` while keeping `prepare_private_dataplane`, the hostname, and the certificate. Coordinate the client and Braintrust API URL cutover. This removes CloudFront and opens the internal HTTP:8000 callback path. The ALB HTTP:80 listener remains, with CloudFront admission removed.

To return to public mode, set `enable_private_dataplane = false` and keep the other three inputs. CloudFront is recreated against HTTP:80; HTTPS:443 stays available. The new CloudFront distribution can have a different AWS hostname, so review DNS and `api_url` before directing clients back to it. Retest API, proxy, Loop, and callbacks.

After public access is healthy, remove the ALB hostname and certificate and set `prepare_private_dataplane = false` to delete the separate HTTPS:443 listener. If a customer-owned NLB targets this ALB on port 443, first deregister the ALB target and wait until draining finishes. AWS requires an ALB target group's port to match an ALB listener and does not permit removing the listener while that target is registered. The module cannot coordinate a customer-owned NLB's lifecycle.

## Existing private or public HTTPS listener

For a v7 deployment whose existing `api_ecs_http` listener is HTTPS:443, **keep the ALB hostname and certificate during the v8 upgrade**. Do not set `prepare_private_dataplane` on that existing listener. The upgrade leaves it at 443 and adds HTTP:80 independently. Public mode uses the new HTTP path; private mode keeps it closed by security group.

If that deployment is already public, also set `allow_legacy_public_https_listener = true` for the upgrade. This explicit opt-in distinguishes an existing 443 listener from a new attempt to turn an HTTP:80 listener into HTTPS in public mode. Without it, Terraform rejects the configuration before making changes. Keep the opt-in while the legacy certificate remains configured in public mode.

To move an existing private deployment to public mode, first set `enable_private_dataplane = false` and `allow_legacy_public_https_listener = true`, retaining the hostname and certificate. Apply and verify the public CloudFront path. If a customer-owned NLB targets port 443, deregister the ALB and wait for draining. Then, in a later apply, remove the ALB hostname and certificate and set `retire_legacy_api_https_listener = true`, keeping the legacy opt-in. Terraform deletes the old HTTPS listener; the separate HTTP:80 listener and CloudFront route stay in place. Keep both flags set in later applies. For another private staging cycle, set `prepare_private_dataplane = true` with a hostname and certificate while keeping those flags.

`retire_legacy_api_https_listener` is only for a deployment whose original listener was HTTPS:443. Setting it on an original HTTP:80 deployment would attempt to replace the active port 80 listener and is unsupported. Review `terraform state show` and the plan before using it.

If an external NLB still has the ALB registered on 443, its owner must deregister and drain it before the retirement apply. This external prerequisite cannot be made atomic with the module's Terraform apply. Do not remove the 443 listener or its certificate in the same apply that switches from private to public mode.
