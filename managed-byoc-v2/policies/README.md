# IAM policy review guide

These are proposed policy documents, not deployment artifacts. Replace all
placeholders before implementation:

| Placeholder | Meaning |
| --- | --- |
| `<AWS_PARTITION>` | `aws` for this preview; other partitions need a separate compatibility review |
| `<AWS_ACCOUNT_ID>` | Dedicated customer AWS account ID |
| `<AWS_REGION>` | Data plane AWS Region |
| `<BOOTSTRAP_NAME>` | Short identifier for this customer access contract |
| `<MANAGED_RESOURCE_PREFIX>` | Exact configured Terraform `deployment_name` prefix for the data plane |
| `<RUNTIME_BOUNDARY_ARN>` | ARN of `runtime-permissions-boundary.json` after creation |
| `<STATE_BUCKET_NAME>` | Terraform state bucket owned by the customer |
| `<OPERATION_LOG_BUCKET_NAME>` | Operation log bucket owned by the customer |
| `<BRAINTRUST_ARTIFACT_BUCKET_NAME>` | Exact Braintrust deployment artifact bucket for the data plane Region |
| `<STATE_KMS_KEY_ARN>` | State bucket key owned by the customer, if SSE-KMS is used |
| `<OPERATION_LOG_KMS_KEY_ARN>` | Operation log key owned by the customer, if SSE-KMS is used |
| `<BRAINSTORE_BUCKET_NAME>` | Exact Brainstore data bucket created by the module |
| `<DATA_PLANE_KMS_KEY_ARN>` | Exact KMS key created by the module and retained with customer data |
| `<RETAINED_RDS_SNAPSHOT_PREFIX>` | Prefix used for encrypted final RDS snapshots retained during deprovisioning |
| `<LICENSE_SECRET_ARN>` | Exact ARN of the license secret owned by the customer |
| `<LICENSE_SECRET_KMS_KEY_ARN>` | Resolved license secret key ARN; see handling for keys managed by AWS below |

For a license secret key managed by AWS, remove `DecryptLicenseSecret` and put
the resolved `alias/aws/secretsmanager` **key ARN** in the SCP decrypt exception.
For an SSE-S3 bucket, remove its `Use...KeyThroughS3` statement and corresponding
key entries from the SCPs. Never replace an unused key placeholder with `*`.

Bootstrap keys must be distinct from the data plane key managed by the module and
must not carry the module's `BraintrustDeploymentName` tag. Their policies stay
under customer control. The S3 KMS examples use object ARN encryption context;
keep S3 Bucket Keys disabled for these two buckets. Enabling Bucket Keys changes
the context to a bucket ARN and requires an explicit policy update.

The KMS decrypt permission for operation records supports multipart uploads; it
does not grant S3 object reads. Retain bucket versioning and consider Object Lock
for operation records: `PutObject` can otherwise replace the current version.

Terraform also needs [KMS access for encrypted Lambda environment variables](https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars-encryption.html).
This deployment permission applies only through Lambda and only to the data
plane key; it does not permit direct KMS decryption. Confirm the forwarded
service context and provider refresh behavior before production use.

## Role attachment model

| Role | Permissions boundary | Identity policies |
| --- | --- | --- |
| `BraintrustDeploymentRole-<BOOTSTRAP_NAME>` | `deployment-permissions-boundary.json` | `deployment-infrastructure-policy.json`, `deployment-data-policy.json` |
| `BraintrustSupportRole-<BOOTSTRAP_NAME>` | None required; SCP remains effective | `observer-policy.json`, `support-policy.json` |
| `BraintrustObserverRole-<BOOTSTRAP_NAME>` | None required; SCP remains effective | `observer-policy.json` |
| Runtime roles created by Terraform | `runtime-permissions-boundary.json` | Module policies for individual workloads |

The deployment boundary is not a grant: an action must be allowed by an
identity policy and the boundary, and must not be denied by the SCP. The
runtime boundary similarly caps policies that the Terraform module creates for
individual workloads. External feature scope is detailed below.

AWS limits each managed policy document to 6,144 characters, excluding
whitespace. The validation script checks templates and documents rendered with
sample values. Final customer values must also pass. Run
`./validate.sh /path/to/rendered-package` from the package directory to check
final values. Submit SCPs as minified JSON.
The policy set is intentionally coarse: two deployment identity policies, two
boundaries, one diagnostic policy shared by both human roles, and one compact
Support operations policy.

`observer-policy.json` is the common human diagnostic baseline. The Support
role also receives `support-policy.json`; the Observer role does not. Explicit
denies in the shared policy therefore remain effective for both roles.

If one access contract covers multiple data planes whose `deployment_name`
values do not share a safe prefix, enumerate their ARN patterns and tag values
instead of replacing this placeholder with a broad wildcard.

The ARNs for the two deployment Lambda hooks and the
`/braintrust/<deployment_name>/` SSM path use an exact deployment name. Enumerate
these for multiple data planes.
The state example uses a separate backend prefix per deployment and S3 lock
files (`*.tflock`), not Terraform workspace deletion. The implementation must
verify backend discovery/list requests without granting access to other state.

Some identifiers, including the retained data plane key ARN, exist only after
creation. Before production use, the implementation must validate how it binds
these values into controls owned by the customer without exposing a running data
plane before protection is effective.

## External feature policy notes

The management-role S3 SCP uses `aws:ResourceAccount` only when AWS supplies
owner context; it does not cap every S3 API or other AWS services. The deployment
identity policy grants read-only access to the named Braintrust software bucket.

The current module uses `Resource: "*"` when its Bedrock or S3 export role
allowlist is empty. The baseline runtime boundary's `sts:AssumeRole` deny blocks
those paths. Before enabling either feature, set exact destination role ARNs in
the source workload policy and exclude only those ARNs from the boundary deny.
That boundary change does not grant access on its own: restrict destination
trust and permissions to the intended workload. The shared boundary exception
is not workload-specific.

The runtime boundary does not impose a universal owner-account limit on direct
S3, KMS, or other service calls. External resources therefore need exact source
policy scope and matching destination resource or key policies. Add
service-specific controls and audit coverage for each enabled feature.

## Support operations

Support uses existing module resource names and tags. Brainstore operations
require both the name prefix and `BraintrustDeploymentName` tag. Lambda concurrency
changes use the function prefix; schedule controls cover only the three module
job names, leaving customer audit rules outside their scope. Keep sensitive values
out of schedule target inputs, which are visible to the human diagnostic roles.

The diagnostic policy deliberately excludes Lambda function/version listings and
task definition reads because those responses can include credentials. Operators
can inspect concurrency and ECS service revisions using known resource names or
ARNs without reading those values. Some AWS console pages may remain unavailable;
the corresponding permitted CLI/API operations remain the intended access path.
