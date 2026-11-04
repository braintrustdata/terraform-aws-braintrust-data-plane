# Temporary Diagnostics access

[Back to overview](README.md#start-here)

Status: design preview; live access and transcript acceptance remain pending.

Diagnostics provides temporary operational and troubleshooting access.
It can read or modify customer data and may provide root access on managed
hosts or inside containers. Logs and configuration may expose sensitive
content even without a shell.

## Activation and closure

- Bootstrap creates the Diagnostics role with no attached policies.
  Activation attaches shared inspection and the combined
  [Diagnostics policy](policies/README.md#role-attachment-model).
- Deployment can attach/detach only those two policies on the exact role.
  It cannot rewrite them, replace the role, or change its trust.
- One activation covers all data planes under the bootstrap. Engineers use
  individual attributed SSO sessions, not shared credentials.
- Braintrust records the authorizing actor, reason, scope, approval reference,
  start, expiry, extensions, and closure result. The default window is two hours;
  chained AWS credentials last at most one hour.
- Activation verifies logging and delivers its operation record before granting
  access. Closure or expiry removes permissions, terminates associated sessions,
  and verifies absence. Partial failures remain pending and retryable.

Braintrust handles activation. A recorded customer approval or applicable
standing approval is required. This is process approval, not a customer-owned
technical gate that Braintrust cannot bypass. Customer-configurable activation
modes are not part of this preview.

Do not grant Diagnostics or its sessions independent access through resource
policies; an inactive role must have no effective diagnostic access.

## Permitted access

| Path | Scope |
| --- | --- |
| Session Manager shell | Instances with matching `BraintrustDeploymentName` and recognized `BrainstoreRole` tags; exact logged shell document |
| ECS Exec | Clusters and tasks under the managed prefix |
| Application logs | Matching `/braintrust/`, `/ecs/`, `/aws/lambda/`, and Loop MicroVM groups |
| Workload configuration | Task definitions, user data, and launch configurations |
| Operational changes | Scoped scaling, task recovery, Lambda concurrency, module schedules, database/cache reboot, and database parameter tuning |

Some configuration and discovery reads apply across the account and Regions;
the managed prefix is not complete isolation between data planes.

We use standard Session Manager shells, not SSH or port forwarding. The role
does not grant generic Run Command, EC2 Instance Connect, IAM administration,
outbound role assumption, or direct state/object/secret/database API reads.
Workload credentials and shell access can still reach and modify data.

ECS Exec traffic uses the module's KMS key. The Diagnostics grant for
`kms:GenerateDataKey` supports that session transport, not direct decryption.

## Logging requirements and limits

Bootstrap creates:

- Session document `BraintrustDiagnosticsShell-<BOOTSTRAP_NAME>`, using
  `Standard_Stream` and CloudWatch streaming with no caller-controlled
  logging destination or session type.
- Log group `/braintrust-byoc/<BOOTSTRAP_NAME>/diagnostics`, with 90-day
  retention and default CloudWatch encryption. No additional transcript KMS
  key is required.

The module must enable SSM/ECS Exec and provide instance/task transcript-write
permissions. ECS logging must use `OVERRIDE` to this group, with images and
network access that support capture. IAM JSON alone does not configure delivery.

Deployment retains ECS cluster management, including Exec logging settings.
Activation verifies the destination and configuration; unexpected drift during
access triggers closure and cleanup. Missing logging blocks activation.

CloudTrail records AWS API activity; CloudWatch holds command/output transcripts.
Management roles have no direct transcript-write grant. Workloads deliver
transcripts, and a privileged shell can interfere with capture or use workload
credentials. Logging does not guarantee a complete record of every action.

See the [logging diagram and monitoring guide](guardrails/cloudtrail-alerting.md)
for customer-owned destinations and optional separate archival.

## Customer revocation

To end access, the customer can use its normal AWS administration process to:

1. Remove Braintrust from role trust to block new assumptions.
2. Detach both activation policies and revoke already-issued role sessions.
3. Terminate active Session Manager and ECS Exec connections.
4. Verify no diagnostic attachments or attributable sessions remain.

Deployment cannot restore trust removed by the customer. Trust removal,
attachment removal, or an expired window alone does not prove closure.
Braintrust verifies session ownership and leaves unrelated sessions alone;
missing attribution keeps cleanup pending rather than reporting success.
Unavailability of the deployment service or revoked machine authority may delay
automatic cleanup, so customer recovery access must remain independent.

References: [SSM access](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html),
[ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html),
[role session revocation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html).
