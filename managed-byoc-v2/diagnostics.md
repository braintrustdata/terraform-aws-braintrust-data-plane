# Temporary Diagnostics access

[Back to overview](README.md#start-here)

Status: design preview; live access and transcript acceptance remain pending.

Diagnostics provides temporary operational and troubleshooting access.
It can read or modify customer data and may provide root access on managed
hosts or inside containers. Logs and configuration may expose sensitive
content even without a shell.

## Activation and closure

- Bootstrap attaches inspection and the predefined
  [Diagnostics policy](policies/README.md#role-attachment-model), with
  [closed trust](trust-policies/diagnostics-role-trust-policy.json).
- Braintrust's deployment service uses the customer Deployment role to replace
  that trust with a [temporary grant](trust-policies/diagnostics-active-trust-policy.json):
  the exact Braintrust Diagnostics source role, named engineers' authenticated
  source identities, and the window's start and expiry. It does not change SSO
  assignments or the Diagnostics permissions policies.
- One activation covers all data planes under the bootstrap. Only named
  participants may assume Diagnostics during the window; eligibility for the
  shared Braintrust source role alone is not enough.
- Braintrust records the authorizing actor, named participants, reason, scope,
  approval reference, start, expiry, extensions, and closure result. The default
  window is two hours; chained AWS credentials last at most one hour.
- Activation verifies logging and delivers its operation record before opening
  trust, then reads back the resulting policy. Participant changes and extensions
  update the recorded grant. A failed update is not reported as successful access.
- At the deadline, the trust condition blocks new assumptions even if the
  deployment service is unavailable. Early closure restores closed trust;
  expiry also schedules restoration of that baseline. Failed restoration stays
  visible and retryable, without extending the expired grant.

```mermaid
flowchart TB
    subgraph BT[Braintrust]
        S["Diagnostics source role<br/>Standing SSO eligibility"]
        B[BYOC deployment service]
    end
    subgraph CUSTOMER[Customer AWS account]
        D[Deployment role]
        subgraph G[Diagnostics role]
            T["Trust policy<br/>Closed or named engineers + deadline"]
            P["Fixed permissions<br/>Inspection and Diagnostics"]
            T -->|controls role assumption| P
        end
    end
    B -.->|temporary operation credentials| D
    D -.->|replace trust for the access window| T
    S -->|individual source identity checked| T
```

The customer can inspect the source role, permitted source identities, and
deadline in its own IAM console or API. CloudTrail records trust changes and
successful role assumptions. The closed and active examples are alternative
complete trust documents, not statements to combine.

Braintrust handles activation. A recorded customer approval or applicable
standing approval is required. This is process approval, not a customer-owned
technical gate that Braintrust cannot bypass. Customer-configurable activation
modes are not part of this preview.

Deployment's `iam:UpdateAssumeRolePolicy` is limited to the exact Diagnostics
role, but AWS does not constrain the replacement document to the example's
participants or deadline. Braintrust's activation workflow must enforce those
rules. Fixed permissions and customer guardrails still limit the assumed role.

Do not add alternative assumption grants or independent session permissions
through resource policies; these can bypass the intended access path.

## Expiry and existing sessions

Closing or expiring trust stops new assumptions, not credentials already issued.
Those credentials can authorize new API calls and shell connections until their
own expiry. An established shell can continue beyond credential expiry.
Routine closure does not revoke AWS sessions or terminate connections.

Configure the logged SSM document with a 60-minute maximum session duration and
20-minute idle timeout. ECS Exec has a fixed 20-minute idle timeout, not an
absolute maximum duration. A two-hour activation window is therefore not a
two-hour maximum for all ongoing access. Emergency revocation is separate.

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
Activation verifies the destination and configuration. Missing logging blocks
activation; unexpected drift triggers investigation and closes trust to new
assumptions. Existing sessions are subject to the limits above.

CloudTrail records AWS API activity; CloudWatch holds command/output transcripts.
Management roles have no direct transcript-write grant. Workloads deliver
transcripts, and a privileged shell can interfere with capture or use workload
credentials. Logging does not guarantee a complete record of every action.

See the [logging diagram and monitoring guide](guardrails/cloudtrail-alerting.md)
for customer-owned destinations and optional separate archival.

## Customer revocation

To end access, the customer can use its normal AWS administration process to:

1. Prevent Deployment from updating the Diagnostics trust, using an independent
   customer-controlled IAM or organization restriction, or revoke Deployment
   access, including issued credentials. Removing Diagnostics trust alone is
   reversible by Deployment.
2. Restore closed Diagnostics trust to block new assumptions.
3. If immediate cutoff is needed, revoke issued Diagnostics role sessions and
   terminate active Session Manager and ECS Exec connections. Confirm the
   resulting access state with independent customer recovery access.

Revocation procedures must account for IAM propagation and active connections.
Changing a role's trust policy does not by itself control who may edit that policy.

References: [SSM access](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html),
[ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html),
[role session revocation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html).
