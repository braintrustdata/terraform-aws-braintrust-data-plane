# IAM policy reference

[Back to overview](../README.md#start-here)

Use the attachment map to review effective grants. Names and inputs below are
implementation requirements; placeholders do not need substitution for review.

## Role attachment model

| Role | Boundary | Attached policies |
| --- | --- | --- |
| `BraintrustDeploymentRole-<BOOTSTRAP_NAME>` | None | Five deployment policies below |
| `BraintrustObserverRole-<BOOTSTRAP_NAME>` | None | [inspection-policy.json](inspection-policy.json) |
| `BraintrustDiagnosticsRole-<BOOTSTRAP_NAME>` | None | Inspection and [diagnostics-policy.json](diagnostics-policy.json), only while active |
| Runtime roles created by Terraform | [runtime-permissions-boundary.json](runtime-permissions-boundary.json) | Module policies for each workload |

Identity policies grant role capabilities. The runtime boundary limits delegated
workload grants; it is not attached to management roles and grants no access itself.
The [SCP](../guardrails/README.md) protects selected account safeguards rather
than repeating each role's restrictions.

Inspection uses read families where safe. EC2 user data, launch configuration
contents, and ECS task definitions are excluded from inspection and added only
by Diagnostics. Names, tags, stack outputs, and task overrides must not contain
secrets or customer payloads; permitted metadata APIs expose them. Some AWS
console pages need content reads that Observer does not have. Use the permitted
CLI/API calls instead of broadening access for console convenience.

Inspection covers the supported data plane, not a general AWS inventory.
Unused VPN, edge hardware, VM import/export, DynamoDB, and EFS reads are omitted.
Core networking, capacity, quotas, and EKS metadata remain available to both
human roles.

Do not grant bootstrap roles or workload role sessions independent permissions
through resource policies. Such grants can bypass implicit identity or boundary
limits. See [AWS policy evaluation](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html).
The customer controls those policies and must review their interaction with
the attached IAM grants.

Keep the module's legacy `enable_braintrust_support_logs_access` and
`enable_braintrust_support_shell_access` options `false`; they create an
access path outside this model.

## Deployment policy files

Five managed policies attach to one role to stay within AWS document limits.

| File | Purpose |
| --- | --- |
| [deployment-infrastructure-policy.json](deployment-infrastructure-policy.json) | Service lifecycle, networking, delegated IAM, and data-plane key administration |
| [deployment-data-policy.json](deployment-data-policy.json) | State, operation records, bucket configuration, and required secrets |
| [deployment-workload-policy.json](deployment-workload-policy.json) | Lambda configuration/hooks, monitoring, and ordinary log configuration |
| [deployment-diagnostics-policy.json](deployment-diagnostics-policy.json) | Two exact activation pairs, logging verification metadata, and session cleanup |
| [deployment-eks-policy.json](deployment-eks-policy.json) | Scoped EKS management |

Deployment remains privileged. Broad EC2, RDS, and SQS lifecycle permissions
include service-returned content such as console output, database logs, and queue
messages. They are not a read-only or data-blind identity. CloudWatch log-event
reads and interactive ECS/SSM entry are not granted. Ordinary log management
excludes the diagnostic transcript group.

Lambda invocation is limited to prefixed `MigrateDatabaseFunction`,
`QuarantineWarmupFunction`, and `BrainstoreDeployment` hooks, unqualified or
at `$LATEST`. It does not allow arbitrary function invocation.

## Naming and scope

Reserve one non-overlapping prefix per bootstrap, ending in a hyphen, such as
`bt-a-`. Every managed `deployment_name` must begin with it; the module limits
that name to 18 characters. One bootstrap may cover multiple data planes.

| Resource | Required naming |
| --- | --- |
| Management roles, under IAM path `/braintrust-byoc/` | `Braintrust{Deployment,Observer,Diagnostics}Role-<BOOTSTRAP_NAME>` |
| Runtime boundary, under the same path | `BraintrustRuntimeBoundary-<BOOTSTRAP_NAME>` |
| Activation policies, under the same path | `BraintrustInspectionPolicy-<BOOTSTRAP_NAME>` and `BraintrustDiagnosticsPolicy-<BOOTSTRAP_NAME>` |
| Other bootstrap managed policies | Same path; names ending in `-<BOOTSTRAP_NAME>` |
| Runtime roles, policies, and instance profiles | Root path `/`; names beginning with `<MANAGED_RESOURCE_PREFIX>` |

The IAM path is part of the ARN, not the role name. Bootstrap bucket names must
be outside the runtime prefix. Inline policies inherit their parent role.

Created runtime roles require the exact boundary. Deployment can manage
prefixed role policies and trust, but not the bootstrap roles or boundary.
`PassRole` is constrained by resource and service; RDS receives its monitoring
role through `rds.amazonaws.com`, while that role trusts
`monitoring.rds.amazonaws.com`. Listed service-linked roles use AWS-managed
permissions and are not constrained by the runtime boundary or SCP.

Key creation and administration require
`BraintrustDeploymentName = deployment_name` within the managed prefix.
Do not override or remove this ownership tag. These references cover
module-created data-plane keys, not externally supplied keys.

Examples target the `aws` partition and one Region. Some infrastructure grants
are account-wide; the prefix is not complete isolation between data planes.
Brainstore operational permissions use module names and deployment tags.
Schedule controls cover only the module's three named jobs.

## Inputs

| Placeholder | Meaning |
| --- | --- |
| `<AWS_PARTITION>` | `aws`; other partitions need compatibility validation |
| `<AWS_ACCOUNT_ID>`, `<AWS_REGION>` | Dedicated account and data-plane Region |
| `<BOOTSTRAP_NAME>` | 1–16 lowercase letters, digits, or hyphens; start with a letter or digit |
| `<MANAGED_RESOURCE_PREFIX>` | 2–8 lowercase letters, digits, or hyphens; start with a letter or digit and end in a hyphen |
| `<RUNTIME_BOUNDARY_ARN>` | Exact runtime boundary ARN from the naming table |
| `<DIAGNOSTICS_ROLE_ARN>`, `<DIAGNOSTICS_POLICY_ARN>` | Exact role and policy from this bootstrap |
| `<DIAGNOSTICS_ROLE_ID>` | Immutable IAM RoleId from Diagnostics creation, used for session cleanup |
| `<STATE_BUCKET_NAME>`, `<OPERATION_LOG_BUCKET_NAME>` | Distinct customer-owned S3 buckets, outside the runtime prefix |
| `<BRAINTRUST_ARTIFACT_BUCKET_NAME>` | Exact Braintrust software bucket for the Region |
| `<LICENSE_SECRET_ARN>` | Exact same-account, same-Region license secret ARN, at most 128 characters |

[Trust inputs](../trust-policies/README.md) identify the Braintrust principals
and External ID. All final identifiers must be exact; never substitute `*`
for an unused value.

Bootstrap state and operation buckets use versioning and SSE-S3 encryption.
No separate bootstrap KMS key is required or supported by this contract.
The license secret uses default AWS-managed `aws/secretsmanager` encryption.
The module creates a separate data-plane key.

State access is limited to the bootstrap root and per-deployment backend keys.
Only `*.tflock` objects have a direct delete grant. Operation records have
`PutObject`, not an object-read grant. Versioning preserves prior versions;
writes can still replace the current version. Additional Object Lock retention
is a customer control, not a guarantee of this package.

## Diagnostics constraints

Inactive Diagnostics has neither activation policy attached. The Deployment
policy allows only the two exact role/policy attachment pairs and cannot rewrite
their contents, change trust, or attach them elsewhere.

Session Manager entry requires the logged document and both deployment and
Brainstore role tags. ECS Exec targets the managed prefix. Session transport
uses `ssmmessages:OpenDataChannel` with `Resource: "*"`; target authorization
remains on `StartSession` and `ExecuteCommand`.

The cleanup grant uses the original Diagnostics RoleId for SSM shells and the
reserved ECS target tag for ECS sessions. Regional `cloudtrail:LookupEvents`
supports ECS actor attribution; it cannot be IAM-scoped to one event name.
These grants are not permission to read transcripts or unrelated sessions.
See [Diagnostics](../diagnostics.md) for activation, verification, and revocation.

## External feature requirements

The base boundary permits the API handler to assume only prefixed internal
`QuarantineInvokeRole` and `AIProxyInvokeRole` targets. Module-generated target
trust identifies that data plane's API handler.

Bedrock and S3 export require exact destination roles in workload policies,
matching boundary allowances, and destination trust for the intended workload.
The module's empty feature allowlist can produce `Resource: "*"`; configure
explicit destinations before enabling the feature. A boundary allowance alone
does not grant access.

Direct S3, KMS, and other service calls have no universal ownership perimeter in
this package. Scope each integration's source and destination policies and
monitor activity in the destination account too.

## Additional permissions and validation

The EKS policy reserves scoped AWS management permissions. It does not install
Kubernetes authorization or implement Kubernetes diagnostic access.

The optional `./validate.sh` checks these policy references. A supplied directory
must preserve this layout with final values; it is not the CloudFormation handoff.
`VALIDATE_WITH_AWS=1` additionally uses IAM Access Analyzer.
These checks verify syntax, sizes, and static constraints, not live behavior.
Actual deployment, role assumption, allowed/denied access, logging, and cleanup
require separate acceptance.
