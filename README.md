# Braintrust Terraform Module

For the latest guidance, always refer to the official Braintrust documentation:

- [Self-hosting overview](https://www.braintrust.dev/docs/admin/self-hosting)
- [Upgrade your deployment](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/routine)
- [Data Plane 2.0 upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/v2)

This module is used to create the VPC, Databases, Lambdas, and associated resources for the self-hosted Braintrust data plane.

## Major versions

Always upgrade **one major version at a time**. For example, go from v4 → v5 → v6. Do not jump from v4 directly to v6.

Each major version may include required configuration changes or a multi-step apply sequence. Follow the migration guide for the version you are upgrading to before applying, and review the [routine upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/routine) for the general process of updating the module version and applying changes.

- [Migrating from v5 to v6](MIGRATION_V6.md)

### Brainstore and API upgrades

A normal `terraform apply` waits for the reader and, when enabled, fast-reader Brainstore fleets before updating the API ECS services and the API, catchup ETL, automation, and billing Lambda functions. Their launch-template updates keep the existing ASGs and use a deployment Lambda to start and wait for instance refreshes. The writer and AutomationWriter pools use their own asynchronous ASG instance refreshes and do not block API updates.

For the gated reader fleets, the helper checks the exact numbered launch-template version, ASG and target health, and termination of old instances. Healthy instances from the previous version do not satisfy it. Refreshes can temporarily double capacity to preserve availability. API deployments remain blocked if a gated refresh fails, health checks fail, or the final attempt reaches its 14-minute waiting budget. Terraform automatically invokes the controller a second time during the same apply after the first waiting budget expires, resuming the active refresh with another 14-minute budget. The final invocation also rechecks readiness when the first attempt completes. Fix any reported failure and rerun `terraform apply`; the gate rechecks AWS state and resumes an active refresh. Each retry gets a fresh waiting budget and inspects live AWS state.

The module installs the deployment Lambda from a regional Braintrust artifact using the active API release tag: the ECS API version when `enable_ecs_api` is true, or the API Lambda version otherwise. The corresponding `braintrust_api_version_override` or `lambda_version_tag_override` is respected. Customers need only Terraform and its providers; no local scripts, build tools, CloudFormation stack, or additional service credentials are required. The Terraform identity needs `lambda:InvokeFunction` on the deployment function, in addition to its existing resource-management permissions. Lambda logs include fleet progress and refresh IDs under `/braintrust/<deployment>/<deployment>-BrainstoreDeployment`.

This ordering applies only to the module-managed reader and fast-reader Brainstore EC2 fleets. External EKS deployments retain their own rollout process. Bootstrap resources, including database migrations and the AI Proxy Lambda, remain available before Brainstore starts. Existing API versions must remain compatible with the new Brainstore version during the rollout. Manual ASG replacements sharing an existing target group are rejected while old targets remain; they are outside the in-place launch-template rollout path.

## How to use this module

To use this module, **copy the [`examples/braintrust-data-plane`](examples/braintrust-data-plane) directory to a new Terraform directory in your own repository**. Follow the instructions in the [`README.md`](examples/braintrust-data-plane/README.md) file in that directory to configure the module for your environment.

The default configuration is a large production-sized deployment. Please consider that when testing and adjust the configuration to use smaller sized resources.

If you're using a brand new AWS account for your Braintrust data plane you will need to run ./scripts/create-service-linked-roles.sh once to ensure IAM service-linked roles are created.

## Module Configuration

All module input variables and outputs are documented inline in the module's Terraform files (see `variables.tf`, `outputs.tf`, and the submodules for details).

### Organization access configuration

Prefer ID-based organization access for new deployments:

```hcl
primary_org_name = "your-org-name"
allowed_org_ids  = "00000000-0000-4000-8000-000000000001,00000000-0000-4000-8000-000000000002"
```

`allowed_org_ids` is a comma-separated list of Braintrust Org IDs, not org names. Do not include spaces. You can find an org ID by hovering over the org name in the Braintrust UI. If you keep `braintrust_org_name` set to a specific org name for compatibility, that org is allowed by name today; include its Braintrust Org ID in `allowed_org_ids` for forward compatibility. `braintrust_org_name` remains supported for compatibility, but Braintrust plans to move toward ID-based configuration.

### BTQL audit logging

BTQL `query.read` audit logging is disabled by default. Enable it for specific Braintrust Org IDs with either strict or best-effort mode. The two modes are mutually exclusive.

```hcl
# Strict mode
btql_audit_logs_strict_org_ids = ["00000000-0000-4000-8000-000000000001"]

# Or best-effort mode
btql_audit_logs_best_effort_org_ids = ["00000000-0000-4000-8000-000000000001"]
```

Strict mode writes audit rows before returning query results. Best-effort mode writes audit rows asynchronously and logs failures.

### S3 Block Public Access ownership

By default, the module manages all four Block Public Access settings on its
Brainstore, code bundle, Lambda response, and optional VPC flow-log buckets.

For a **new deployment** where your security controls prohibit these writes, set:

```hcl
manage_s3_public_access_block = false
```

This skips the bucket-level configuration resources; it does not set any
protection to `false`. [AWS enables Block Public Access on new buckets by default](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html).
The customer owns maintaining these protections, preferably through protected
account or organization controls. An SCP denying configuration changes does not
itself enable Block Public Access. Bucket policies, encryption, versioning, and
other module-managed settings remain unchanged. Caller-provided buckets remain
outside this module's ownership.

Leave the default enabled for existing deployments. Changing it from `true` to
`false` plans deletion of the existing bucket-level configurations and requires
the same permission the SCP may prohibit; it is not a supported ownership
handoff for an existing deployment.

## Loop runtime

Loop runtime is optional. Enable it with this input:

```hcl
enable_loop_runtime = true
```

When `enable_ai_gateway` is true, Loop sends model requests to the private AI gateway.
Otherwise, Loop uses the hosted gateway or the CloudFront API proxy.

Loop connects to MicroVM endpoints through an interface VPC endpoint in the main VPC.
The endpoint policy allows connections only to MicroVMs in the deployment account.
The public MicroVM endpoint remains available because AWS does not support its removal.

### Startup dependencies and upgrades

Loop ingress rules are owned by the database, Redis, Brainstore, and gateway
modules. Their internal `loop_runtime_security_groups` maps are separate from
baseline `authorized_security_groups`: Loop waits for Gateway startup, which
indirectly waits for database migration. Combining the maps would delay the
migration Lambda's own database access until after migration succeeds.
The database connection address waits for baseline ingress, but not Loop
ingress. This changes creation order without broadening network permissions.

State moves preserve existing Loop rules from their original Loop-module
addresses. Downgrading after these moves is not safe without a reviewed state
migration: older versions can
destroy/recreate the rules. These address changes require a major release and
the corresponding migration guide before publication.

### Sandbox isolation

The default `loop_runtime_sandbox_egress_mode = "restricted"` creates a dedicated VPC for sandbox egress.
The VPC has no outbound route and blocks DNS requests.
This network isolates untrusted sandbox code from internal networks.

You can supply a dedicated sandbox VPC with these inputs:

```hcl
loop_runtime_sandbox_existing_vpc_id              = "vpc-0123456789abcdef0"
loop_runtime_sandbox_existing_private_subnet_1_id = "subnet-0123456789abcdef0"
loop_runtime_sandbox_existing_private_subnet_2_id = "subnet-0123456789abcdef1"
loop_runtime_sandbox_existing_private_subnet_3_id = "subnet-0123456789abcdef2"
```

The module verifies that each subnet belongs to the supplied VPC.
The module also creates a security group without outbound rules.
The caller controls routes and DNS restrictions in the supplied VPC.

Do not use the sandbox VPC for access to internal services. Untrusted code can use that access.
Configure equivalent DNS restrictions before you enable Loop with a supplied VPC.

## Useful scripts

### dump-logs.sh

This script will dump the logs for the given deployment and services to the `logs-<deployment_name>` directory. This is useful for debugging issues with the data plane and sharing with the Braintrust team.

```bash
# ./scripts/dump-logs.sh <deployment_name> [--minutes N] [--service <svc1,svc2,...|all>]

./scripts/dump-logs.sh bt-sandbox
Fetching logs for the last 60 minutes for APIHandler...
Fetching logs for the last 60 minutes for braintrust-api...
Fetching logs for the last 60 minutes for braintrust-api-ingest...
Fetching logs for the last 60 minutes for braintrust-api-background...
Fetching logs for the last 60 minutes for brainstore...
✅ Saved logs for brainstore to logs-bt-sandbox/brainstore.log
✅ Saved logs for braintrust-api to logs-bt-sandbox/braintrust-api.log
✅ Saved logs for braintrust-api-ingest to logs-bt-sandbox/braintrust-api-ingest.log
✅ Saved logs for braintrust-api-background to logs-bt-sandbox/braintrust-api-background.log
✅ Saved logs for APIHandler to logs-bt-sandbox/APIHandler.log
```

### create-service-linked-roles.sh

Required for new AWS accounts to ensure IAM service-linked roles are created.

```bash
./scripts/create-service-linked-roles.sh
```

### VPCs

This module creates two VPCs by default:

- `main` VPC: This is the main VPC that contains the Braintrust services.
- `quarantine` VPC: This is a "quarantine" VPC where user defined functions run in an isolated environment. The Braintrust API server spawns lambda functions in this VPC.

#### VPC endpoints

The module creates these AWS service endpoints in VPCs it manages:

| Service | Type | Created when | Private DNS |
| --- | --- | --- | --- |
| S3 | Gateway | Always, in both main and quarantine VPCs when created; attached to their private route tables | Not applicable |
| SSM (`ssm`, `ssmmessages`, `ec2messages`) | Interface | Main VPC with `enable_brainstore_ec2_ssm = true` (default `false`) and `create_ssm_vpc_endpoints = true` (default `true`) | Enabled |
| Secrets Manager | Interface | Main VPC with `create_secrets_manager_vpc_endpoint = true` (default `true`) | Enabled |

SSM and Secrets Manager endpoints span all three private subnets and share a
security group allowing HTTPS (TCP 443) from the VPC CIDR. Private DNS lets
existing SDK and CLI calls use the endpoints without URL overrides. Interface
endpoint charges apply.

To keep Brainstore SSM access enabled while supplying your own SSM connectivity,
set `enable_brainstore_ec2_ssm = true` and `create_ssm_vpc_endpoints = false`.
This opts out of all three module-managed SSM endpoints without changing the
Brainstore SSM IAM permissions. Provide reachable customer-managed endpoints
(including DNS and security groups) or outbound HTTPS access to SSM. Disabling
this option on an existing deployment removes its module-managed SSM endpoints.
The shared endpoint security group remains while Secrets Manager needs it.
S3, Secrets Manager, and quarantine endpoints are unaffected. The option has no
effect when `create_vpc = false`.

Secrets Manager is enabled by default independently of SSM. Upgrading a deployment
with a module-managed main VPC adds the endpoint and redirects regional Secrets
Manager calls through it. Set `create_secrets_manager_vpc_endpoint = false` to
retain the previous network path and avoid the additional endpoint charges.
The option has no effect when `create_vpc = false`.
The module does not create these AWS service endpoints inside supplied existing
VPCs. With `create_vpc = false`, it can still create an S3 endpoint in a separate,
module-managed quarantine VPC.

Separately, `use_private_gateway_quarantine_proxy` can create an interface endpoint
in quarantine for the private gateway when both VPCs are module-managed and the
private gateway is enabled for this path. It uses its endpoint-specific DNS name
with Private DNS disabled; the global gateway origin skips this PrivateLink setup.

### Existing ElastiCache subnet group

By default, the module creates an ElastiCache subnet group from the three main
VPC private subnets. To reuse a customer-managed group, set:

```hcl
existing_elasticache_subnet_group_name = "my-redis-subnet-group"
```

The group must already exist in the deployment region and belong to the data
plane VPC. The module uses its name without creating or managing the group or
its subnet membership. This works with both the legacy Redis cluster and
`use_redis_replication_group = true`.

Leaving `existing_elasticache_subnet_group_name` unset preserves the managed subnet
group and Redis, moving only the group's Terraform address to
`module.redis.aws_elasticache_subnet_group.main[0]`. Downgrading the module on
Terraform 1.10 or newer automatically moves the address back without replacing
the group.

Setting a different subnet-group name replaces the Redis cluster or replication
group and causes downtime; review the plan before applying. Terraform updates the
Redis URL secret with the replacement endpoint. The secret-value change alone
does not redeploy API ECS or Loop services. After the replacement and secret update
complete, force a new deployment of all enabled API ECS services (API, ingest, and
background) and the Loop service so their tasks load the updated secret.
Brainstore's updated user data triggers an autoscaling instance refresh, and
Lambdas that embed `redis_host` update during the apply. The gateway embeds the
Redis host in its task environment, so it also updates during the apply.

Switching to an external group also removes the old module-managed subnet group.
Do not set this input to the module's own group name to transfer ownership: that
would schedule the still-used group for deletion. Keeping the existing managed
group requires leaving this input unset.

### Tagging and Naming

If you have requirements to add custom tags to resources created by the module, you can do so by setting the `default_tags` variable on the AWS provider. The example directory [`examples/braintrust-data-plane`](examples/braintrust-data-plane) shows how to do this.

Example:

```hcl
provider "aws" {
  default_tags {
    tags = {
      YourCustomTag = "<your-custom-value>"
    }
  }
}
```

The `deployment_name` variable is also used to prefix the names of the resources created by the module wherever possible. It will also be applied as a tag named `BraintrustDeploymentName` to all resources created by the module.

### CloudFront Access Logging

If you need to enable CloudFront standard access logging, you can configure it independently by referencing the `cloudfront_distribution_arn` output from the module. This approach gives you full flexibility over the logging configuration without requiring changes to the module itself.

See the [`examples/cloudfront-logging`](examples/cloudfront-logging) directory for a complete example showing how to set up V2 logging to S3.

### VPC Flow Logs

VPC Flow Logs are disabled by default and only apply to VPCs this module creates (`create_vpc = true` / a module-managed quarantine VPC). Configure the main and quarantine VPCs separately via `main_vpc_flow_log` and `quarantine_vpc_flow_log`.

When enabled, logs go to one of:

- **Customer S3 bucket** — set `destination_arn` to the bucket ARN. Attach a destination policy that grants `delivery.logs.amazonaws.com` `s3:PutObject` and `s3:GetBucketAcl` *before* enabling Flow Logs. `CreateFlowLogs` can succeed even when delivery is denied, so a missing policy looks like an empty bucket.
- **Module-managed S3 bucket** — leave `destination_arn` null. The module creates a `bucket_prefix` bucket with Bucket owner enforced ownership, SSE-KMS using the data-plane key, a log-delivery policy (no `x-amz-acl` condition), and object expiration from `retention_in_days` (set `0` to skip expiration). This bucket does not set `force_destroy`. After Flow Logs have written objects, setting `enabled = false`, changing destination, or destroying the stack fails with `BucketNotEmpty`. That is intentional: the module will not empty audit logs. To delete the logs, empty the bucket (or wait for lifecycle expiration) and apply. To keep the logs when disabling or changing destination (stack stays up), remove the managed bucket and its companion resources from Terraform state, then apply. The data-plane KMS key is left in place, so the objects stay readable.

  Full stack destroy is different. The module-created key uses a 7-day pending-deletion window and is unusable while pending, so retained objects become permanently unreadable unless you also keep that key. Before destroy, remove the key and its alias from state (`module.kms[0].aws_kms_key.braintrust` and `module.kms[0].aws_kms_alias.braintrust` when this module is the root) along with the bucket. Or encrypt the destination with an externally managed CMK from the start (`kms_key_arn` on the flow-log object, or this module's `kms_key_arn` input). Or copy/re-encrypt the objects to another key before destroy.
- **CloudWatch Logs** — set `destination_type = "cloud-watch-logs"`. Pass a bare log-group ARN if you bring your own (no trailing `:*`; the module strips that suffix if present). The module creates an IAM role with an inline delivery policy, matching the rest of this module.

Module-managed destinations are encrypted with the data-plane KMS key (`kms_key_arn` input, or the key this module creates). You do not pass this module's `kms_key_arn` output back into `main_vpc_flow_log` — that is a cycle. Override `kms_key_arn` on the flow-log object only when using a different CMK. That custom key must allow the service principal for the destination: `delivery.logs.amazonaws.com` for S3, or `logs.<region>.amazonaws.com` for a CloudWatch log group. Otherwise delivery fails after `CreateFlowLogs` succeeds.

```hcl
main_vpc_flow_log = {
  enabled         = true
  traffic_type    = "ALL"
  destination_arn = "arn:aws:s3:::my-flow-logs-bucket"
}

quarantine_vpc_flow_log = {
  enabled          = true
  destination_type = "cloud-watch-logs"
}
```

### S3 Server Access Logging

S3 server access logging is disabled by default. Enable it to deliver access logs from the brainstore, code-bundle, and lambda-responses buckets to an S3 bucket you own. This is commonly used for audit and compliance requirements.

Enable logging in this order. The destination policy must already be in place before you set `s3_server_access_logging`; this module only configures the source buckets and cannot depend on a policy you manage outside it.

1. Create the destination bucket (same AWS account and region as the data plane). It must not have Object Lock or Requester Pays enabled, and default encryption must be SSE-S3 (AES256). SSE-KMS prevents Amazon S3 from delivering logs you can decrypt.
2. Deploy the data plane (or use an existing deployment) so the source bucket name outputs are available.
3. Attach a bucket policy on the destination bucket that grants `s3:PutObject` to `logging.s3.amazonaws.com` (see below). Restrict access to the destination bucket; access logs can include object keys and requester information.
4. Only after that policy is applied, set `s3_server_access_logging` and apply again. Use the same prefix as the destination policy `Resource` path (`braintrust/` in the example below). If you omit `prefix`, the module defaults to `<deployment_name>/`, and the policy path must match that instead. Per-bucket suffixes (`brainstore/`, `code-bundle/`, `lambda-responses/`) are appended under the prefix; `braintrust/*` already covers them, so no extra policy statements are needed.

```hcl
s3_server_access_logging = {
  bucket = "your-audit-logs-bucket"
  prefix = "braintrust/"
}
```

Use the `brainstore_s3_bucket_name`, `code_bundle_s3_bucket_name`, and `lambda_responses_s3_bucket_name` outputs for the source bucket names in the destination policy. The `Resource` prefix must match `s3_server_access_logging.prefix` (default `<deployment_name>/` when omitted). Any `Deny` statements on the destination bucket must not block log delivery.

```hcl
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "s3_server_access_logs" {
  statement {
    sid    = "S3ServerAccessLogsPolicy"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::your-audit-logs-bucket/braintrust/*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:s3:::${module.braintrust-data-plane.brainstore_s3_bucket_name}",
        "arn:aws:s3:::${module.braintrust-data-plane.code_bundle_s3_bucket_name}",
        "arn:aws:s3:::${module.braintrust-data-plane.lambda_responses_s3_bucket_name}",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "s3_server_access_logs" {
  bucket = "your-audit-logs-bucket"
  policy = data.aws_iam_policy_document.s3_server_access_logs.json
}
```

Logs are written with a date-partitioned key format:

`<prefix><bucket-role>/<SourceAccountId>/<SourceRegion>/<SourceBucket>/<YYYY>/<MM>/<DD>/...`

For example, `braintrust/brainstore/<account>/<region>/<bucket>/2026/08/12/...`. First log delivery can take a few hours after you enable logging.

### Using an Existing VPC

The module supports using an existing VPC instead of creating a new dedicated one for the Braintrust services. This is useful when you want to integrate Braintrust into your existing network infrastructure.

The passed in VPC must have the following resources:

- At least 3 private subnets in different availability zones
- At least 1 public subnet
- Internet gateway and NAT gateway with proper route tables configured for private subnets

Important note: The module will still create and manage security groups for the services.

To use an existing VPC, set `create_vpc = false` and provide the required VPC details:

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

## Development Setup

This section is only relevant if you are a contributor who wants to make changes to this module. All others can skip this section.

1. Clone the repository
2. Install [mise](https://mise.jdx.dev/about.html):

  ```bash
  curl https://mise.run | sh
  echo 'eval "$(mise activate zsh)"' >> "~/.zshrc"
  echo 'eval "$(mise activate zsh --shims)"' >> ~/.zprofile
  exec $SHELL
  ```

3. Run `mise install` to install required tools
4. Run `mise run setup` to install pre-commit hooks
