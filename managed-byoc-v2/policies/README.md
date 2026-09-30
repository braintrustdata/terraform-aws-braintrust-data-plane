# IAM policy review guide

These are proposed policy documents, not deployment artifacts. Replace all
placeholders before implementation:

| Placeholder | Meaning |
| --- | --- |
| `<AWS_PARTITION>` | `aws` for this preview; other partitions need a separate compatibility review |
| `<AWS_ACCOUNT_ID>` | Dedicated customer AWS account ID |
| `<AWS_REGION>` | Data plane AWS Region |
| `<BOOTSTRAP_NAME>` | Bootstrap identifier: 1–16 lowercase letters, digits, or hyphens; start with a letter or digit |
| `<MANAGED_RESOURCE_PREFIX>` | Reserved deployment prefix: 2–8 lowercase letters, digits, or hyphens; start with a letter or digit and end in a hyphen |
| `<RUNTIME_BOUNDARY_ARN>` | Exact `policy/braintrust-byoc/BraintrustRuntimeBoundary-<BOOTSTRAP_NAME>` ARN |
| `<DIAGNOSTICS_ROLE_ARN>` | Exact bootstrap role `role/braintrust-byoc/BraintrustDiagnosticsRole-<BOOTSTRAP_NAME>` |
| `<DIAGNOSTICS_POLICY_ARN>` | Exact managed policy `policy/braintrust-byoc/BraintrustDiagnosticsPolicy-<BOOTSTRAP_NAME>` |
| `<DIAGNOSTICS_ROLE_ID>` | Immutable IAM `RoleId` returned when bootstrap creates Diagnostics; used to clean up sessions across engineers |
| `<STATE_BUCKET_NAME>` | Terraform state bucket owned by the customer |
| `<OPERATION_LOG_BUCKET_NAME>` | Operation log bucket owned by the customer |
| `<BRAINTRUST_ARTIFACT_BUCKET_NAME>` | Exact Braintrust deployment artifact bucket for the data plane Region |
| `<STATE_KMS_KEY_ARN>` | State bucket key owned by the customer, if SSE-KMS is used |
| `<OPERATION_LOG_KMS_KEY_ARN>` | Operation log key owned by the customer, if SSE-KMS is used |
| `<LICENSE_SECRET_ARN>` | Exact ARN of the license secret owned by the customer; up to 128 characters in this package |
| `<LICENSE_SECRET_KMS_KEY_ARN>` | Resolved license secret key ARN; see handling for keys managed by AWS below |

For a license secret key managed by AWS, remove `DecryptLicenseSecret` and put
the resolved `alias/aws/secretsmanager` **key ARN** in the SCP decrypt exception.
For an SSE-S3 bucket, remove its `Use...KeyThroughS3` statement and corresponding
key entries from the SCPs. Never replace an unused key placeholder with `*`.

Bootstrap keys must be distinct from data plane keys created by the module and
must not carry the module's `BraintrustDeploymentName` tag. Their policies stay
under customer control. The S3 KMS examples use object ARN encryption context;
keep S3 Bucket Keys disabled for these two buckets. Enabling Bucket Keys changes
the context to a bucket ARN and requires an explicit policy update.

The KMS decrypt permission for operation records supports multipart uploads; it
does not grant S3 object reads. Retain bucket versioning and consider Object Lock
for operation records: `PutObject` can otherwise replace the current version.

Terraform also needs [KMS access for encrypted Lambda environment variables](https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars-encryption.html).
This deployment permission applies only through Lambda and only to data plane
keys tagged by the module; it does not permit direct KMS decryption. Confirm the AWS
service request context and provider refresh behavior before production use.

## Naming and scope

One bootstrap can cover multiple data planes. Reserve a managed prefix with a
trailing separator (for example, `bt-a-`); every Terraform `deployment_name`
under that bootstrap must begin with it. Prefixes for different bootstraps in
the account must not overlap or match the same deployment name. The module
limits `deployment_name` to 18 characters.

All bootstrap IAM resources must use the protected `/braintrust-byoc/` path:

| Resource | Required naming |
| --- | --- |
| Four management roles | `Braintrust{Deployment,Support,Observer,Diagnostics}Role-<BOOTSTRAP_NAME>` |
| Runtime boundary policy | `BraintrustRuntimeBoundary-<BOOTSTRAP_NAME>` |
| Deployment boundary policy | `BraintrustDeploymentBoundary-<BOOTSTRAP_NAME>` |
| Diagnostics managed policy | `BraintrustDiagnosticsPolicy-<BOOTSTRAP_NAME>` |
| Other bootstrap managed policies | Names ending in `-<BOOTSTRAP_NAME>`, under the same protected path |
| Runtime roles, managed policies, and instance profiles | Root IAM path `/`, with names beginning with `<MANAGED_RESOURCE_PREFIX>`; never the bootstrap path |

Inline policies belong to their parent role and need not use the resource prefix.

The IAM path is part of the ARN, not the role name. These rules are required for
the SCP selectors and policy protections to apply. Bootstrap bucket names must
not begin with the runtime prefix. Keep bootstrap identifiers short rather than
embedding account, Region, or customer names. The JSON examples cover one
configured Region; some infrastructure permissions apply across the account and are
not isolated by deployment prefix or Region.

The patterns protecting retained data match the module's
`<deployment_name>-brainstore-<generated suffix>` buckets and
`<deployment_name>-main-final-snapshot-<generated suffix>` snapshots. The two
Lambda deployment hooks and `/braintrust/<deployment_name>/` parameters use
the same reserved prefix. New matching data planes are covered without adding
their generated bucket names or KMS key ARNs to the bootstrap policies.

The module tags each key it creates with
`BraintrustDeploymentName = deployment_name`; BYOC configuration must not
override that reserved tag. The deployment policy requires a
matching tag at key creation and for ordinary key administration. The retained
data deny covers key disablement and scheduled deletion in the configured
account and Region, without relying on that tag; the customer guardrail also
prevents the deployment role from removing the ownership tag or changing it
outside the reserved prefix. Externally supplied data plane keys require a
separately documented bootstrap configuration; these samples cover keys
created by the module.
Before production use, test key creation, Lambda and Secrets Manager use,
ordinary updates to tags other than the ownership tag, denied changes to
`BraintrustDeploymentName`, and key deletion protection against the rendered
policies.

## Role attachment model

| Role | Permissions boundary | Identity policies |
| --- | --- | --- |
| `BraintrustDeploymentRole-<BOOTSTRAP_NAME>` | `deployment-permissions-boundary.json` | `deployment-infrastructure-policy.json`, `deployment-data-policy.json`, `deployment-diagnostics-policy.json`, `deployment-eks-policy.json` |
| `BraintrustSupportRole-<BOOTSTRAP_NAME>` | None required; SCP remains effective | `observer-policy.json`, `support-policy.json` |
| `BraintrustObserverRole-<BOOTSTRAP_NAME>` | None required; SCP remains effective | `observer-policy.json` |
| `BraintrustDiagnosticsRole-<BOOTSTRAP_NAME>` | None required; Diagnostics SCP remains effective | `diagnostics-policy.json` only during activation |
| Runtime roles created by Terraform | `runtime-permissions-boundary.json` | Module policies for individual workloads |

The deployment boundary is not a grant: an action must be allowed by an
identity policy and the boundary, and must not be denied by the SCP. The
runtime boundary similarly caps policies that the Terraform module creates for
individual workloads. It denies workloads permission to initiate Session Manager
shells, Run Command, ECS Exec, or EC2 Instance Connect. Instance and task agents
retain the separate transport permissions needed to receive diagnostic sessions
and write transcripts. External feature scope is detailed below.

BYOC v2 deployment configuration must keep the module's legacy
`enable_braintrust_support_logs_access` and
`enable_braintrust_support_shell_access` flags `false`. Those options create a
separate support path outside this bootstrap's human role controls; they are not
part of v2. The deployment workflow must reject either option being enabled.

AWS limits each managed policy document to 6,144 characters, excluding
whitespace. The validation script checks short samples and renders using maximum
input lengths, including 63-character bucket names and the naming limits above. Trust principal
ARNs and External IDs have separate limits in the [trust guide](../trust-policies/README.md).
Final customer values must also pass. Run
`./validate.sh /path/to/rendered-package` from the package directory to check
final values. Submit SCPs as minified JSON.
The policy set separates deployment infrastructure, data, Diagnostics activation,
and future EKS permissions. Boundaries and SCPs enforce the stable restrictions.
The EKS policy reserves bounded permissions in the proposed bootstrap; it does not
provision a cluster or install Kubernetes role bindings.

`observer-policy.json` is the common human diagnostic baseline. The Support
role also receives `support-policy.json`; the Observer role does not. Explicit
denies in the shared policy therefore remain effective for both roles. Do not
attach it to Diagnostics: its explicit session and log denials would block
troubleshooting. Diagnostics has its own minimal discovery permissions.

The state example uses a separate backend prefix per deployment and S3 lock
files (`*.tflock`), not Terraform workspace deletion. The implementation must
verify backend discovery/list requests without granting access to other state.

## Diagnostics policy constraints

The Diagnostics role and policy must use the protected `braintrust-byoc/` path,
outside the runtime resource prefix. Resolve all three Diagnostics placeholders
from the same bootstrap. Role and policy ARNs must be exact, without wildcards.
Do not attach another identity policy or grant access through resource policies.

The deployment boundary permits only the matching role/policy attachment pair.
It also permits reading role metadata, lists of attached policies, and policy contents
to verify activation. Other bootstrap IAM changes remain denied. The condition
using the role ID on `ssm:TerminateSession` permits cleanup of different
engineers' sessions for that Diagnostics role, without authorizing shell access
for deployment automation.

Session transport uses `ssmmessages:OpenDataChannel` with `Resource: "*"`, as
the service authorization reference does not support resource-level scoping for
that action. Target authorization remains on `StartSession` and `ExecuteCommand`.
Resume/termination use session ownership tags provided by AWS. Validate transport
and ownership with the actual federated identity flow. Session discovery is
across the account in the configured Region; cleanup is constrained by role ID.
ECS Exec session ownership and cleanup must also be validated before promising
expiry behavior.

The EKS file is kept separate because the existing deployment policies are
near AWS's size limit. Its fixed groups for access entries are permission preparation,
not an operational Kubernetes access mechanism. See
[Diagnostics](../diagnostics.md) and [Kubernetes permissions](../kubernetes-permissions.md).

## External feature policy notes

The S3 SCP for management roles uses `aws:ResourceAccount` only when AWS supplies
owner context; it does not cap every S3 API or other AWS services. The deployment
identity policy grants read-only access to the named Braintrust software bucket.

The baseline runtime boundary permits only API handler roles under the managed
prefix to assume internal `QuarantineInvokeRole` and `AIProxyInvokeRole` targets.
Each target's trust generated by the module names the API handler from its own data
plane. The shared boundary limits the role types and bootstrap; target trust
restricts access between data planes. Keep that exact trust intact.

The current module uses `Resource: "*"` when its Bedrock or S3 export role
allowlist is empty. The boundary still denies those external paths. Before enabling
either feature, set exact destination ARNs in the source workload policy and
add only those destinations to `DenyOtherRuntimeRoleAssumptions` exceptions.
Restrict each new exception to its intended source workload and destination trust;
an exception to a shared boundary is not itself a grant to a specific workload.

The runtime boundary does not impose a universal limit based on resource
ownership for direct S3, KMS, or other service calls. External resources therefore
need exact source policy scope and matching destination resource or key policies. Add
controls specific to each service and audit coverage for each enabled feature.

## Storage and log content

Deployment can configure S3 buckets under the managed prefix, including the module's
optional S3 ABAC setting and its bucket tag APIs. This does not enable ABAC by
default, grant object reads, or allow bootstrap bucket configuration changes.

Alarm, metric, dashboard, and ordinary log group management remain available.
Deployment, Support, and Observer cannot use Contributor Insights reports,
log anomaly samples, or lookup table contents to bypass the application log
restrictions. Deployment also cannot create Contributor Insights rules or log
anomaly detectors. See AWS's [Contributor Insights access model](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/iam-cw-condition-keys-contributor.html).

## Support operations

Support uses existing module resource names and tags. Brainstore operations
require both the name prefix and `BraintrustDeploymentName` tag. Lambda concurrency
changes use the function prefix; schedule controls cover only the three module
job names, leaving customer audit rules outside their scope. Keep sensitive values
out of schedule target inputs, which are visible to the human diagnostic roles.

`observer-policy.json` excludes Lambda function/version listings and
task definition reads because those responses can include credentials. Operators
can inspect concurrency and ECS service revisions using known resource names or
ARNs without reading those values. Some AWS console pages may remain unavailable;
the corresponding permitted CLI/API operations remain the intended access path.
