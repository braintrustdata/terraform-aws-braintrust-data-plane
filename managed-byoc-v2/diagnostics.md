# Temporary Diagnostics access

Status: design preview; workflow and deployment validation remain outstanding.

Diagnostics is separate from routine Support and Observer access. It permits
investigation of processes, memory, local logs, runtime configuration, and
database or cache behavior through managed hosts and containers. That access
can read or modify customer data and can include root inside a host or container.

## Access and activation

- Bootstrap creates `BraintrustDiagnosticsRole-<BOOTSTRAP_NAME>` and the fixed
  `diagnostics-policy.json` managed policy. The policy is normally unattached.
- Trust is limited to the designated Braintrust engineering source role, with
  the same identity attribution requirements as the other human roles.
- Deployment can attach/detach only that policy on that role. It cannot rewrite
  the policy, change trust, replace the role, or attach the policy elsewhere.
  Metadata reads let it check the role and current policy attachment.
- One activation covers all matching data planes under the bootstrap. Multiple
  engineers use their own SSO sessions; they do not share credentials.
- Braintrust records the authorizing actor, reason, bootstrap, start, expiry,
  extensions, and closure result. The default window is two hours, with explicit
  extensions. Individual chained AWS credentials still last at most one hour.
- The deployment service removes the policy and closes associated active sessions
  on closure or expiry. The preview supplies permissions to discover and terminate
  sessions; reliable cleanup, retries, and attribution still require testing.

The recorded customer setting determines whether diagnostics is disallowed,
requires customer approval, or may be activated at Braintrust's discretion.
Activation by Braintrust is the standard mechanism. A process approval
does not technically prevent the authorized deployment service from activating
access; this preview does not implement an approval gate controlled by the customer.

Do not grant the Diagnostics role or its sessions independent access through
resource policies. It has no diagnostic permissions attached when inactive.
Routine scaling and maintenance continue through Support or deployment.

## Permitted paths

| Path | Scope |
| --- | --- |
| Session Manager shell | EC2 instances carrying both a matching `BraintrustDeploymentName` and a recognized `BrainstoreRole`; exact logged shell document |
| ECS Exec | Matching clusters and tasks under the managed prefix |
| Application logs | Matching `/braintrust/`, `/ecs/`, and `/aws/lambda/` groups, including `/aws/lambda/microvms/bt-loop-<MANAGED_RESOURCE_PREFIX>*` |
| EKS metadata | Matching cluster, node group, and add-on configuration; not Kubernetes authorization |

We use standard Session Manager shells, not SSH or port forwarding sessions.
The role does not grant generic `SendCommand`, EC2 Instance Connect, IAM
administration, role chaining, or direct state, S3 object, secret, or database
API reads. Those restrictions do not prevent data access through a shell: the workload
already has credentials and access to its data.

The current ECS configuration encrypts Exec session traffic with a module KMS
key. Diagnostics includes only `kms:GenerateDataKey` on keys with matching module
tags for that path, not `kms:Decrypt`. This is separate from transcript storage
encryption.

## Logging prerequisites

Bootstrap must create the following before Diagnostics is enabled:

- Session document `BraintrustDiagnosticsShell-<BOOTSTRAP_NAME>`, with
  `sessionType: Standard_Stream`, CloudWatch streaming, and no parameters that
  let callers change the logging destination or session type.
- Log group `/braintrust-byoc/<BOOTSTRAP_NAME>/diagnostics`, with a defined
  retention period and default CloudWatch encryption. No additional customer
  KMS key is required for transcript storage.
- Instance/task permissions to write transcripts to that exact group.

The module must enable Brainstore SSM and ECS Exec, and configure ECS transcript
logging as `OVERRIDE` to that group. The ECS image must support transcript
capture. These prerequisites are not implemented by the IAM JSON.

The Diagnostics SCP protects the shell document and transcript destination from
Braintrust management and runtime changes. Support, Observer, Diagnostics, and
matching runtime roles cannot update ECS clusters. Deployment retains
`ecs:UpdateCluster` for normal lifecycle changes, which also lets it change Exec
logging; IAM cannot independently restrict those logging fields.

The deployment workflow must preserve `OVERRIDE` logging to the protected group,
verify configuration before Diagnostics activation, and monitor it during active
access. Missing or unexpected logging configuration must block activation or
trigger closure and session cleanup. These checks and cleanup remain
implementation and testing requirements, not completed guarantees.

CloudTrail records role assumptions, activation changes, and session APIs.
CloudWatch stores shell/container transcripts. Delivered records are protected
from the listed AWS API changes. Management roles cannot directly create streams
or insert transcript events; instance and task roles must retain delivery access.
A privileged shell can interfere with capture or use workload credentials;
transcripts cannot guarantee a complete or independently verified record of
every action.
See the [monitoring guide](guardrails/cloudtrail-alerting.md).
The [logging diagram](README.md#logging-and-operation-records) shows the separate
evidence paths and destinations owned by the customer.
Local collection is the default. For stronger separation, the customer can
replicate transcripts to its audit archive account, with replication and
retention controlled by its security team and no Braintrust management access
to that archive.

## Customer revocation

Customers can remove Braintrust from Diagnostics trust to block new assumptions.
For ongoing access, also detach the policy, revoke issued role sessions, and
terminate active diagnostic sessions. Trust removal or policy detachment alone
does not terminate every existing connection. Braintrust's deployment role cannot
restore removed trust.

Session ownership and cleanup must be tested with the actual SSO chain and ECS
Exec path. The cleanup policy uses the Diagnostics role's immutable IAM role ID,
not a session name prefix chosen by an engineer. Kubernetes activation and session
handling are outside this preview's implementation scope.

References: [SSM policy examples](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-examples.html),
[ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html),
[revoking role sessions](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html).
