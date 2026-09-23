# Customer service control policies

The example SCPs in this directory provide additional controls for the dedicated
AWS account. The customer owns these controls. Customer AWS Organizations
administrators review, customize, test, and attach both policies to the
dedicated account or OU.

`customer-service-control-policy.json` protects the access model. Its
main controls are:

- require the runtime boundary owned by the customer when deployment automation
  creates a role;
- constrain role creation and `PassRole` to the reviewed resource prefix;
- prevent the deployment role from editing bootstrap roles and policies;
- prevent Braintrust roles from disabling customer audit controls;
- deny direct application object and secret reads outside documented machine
  exceptions, and cap KMS decryption by key, service, and encryption context;
- deny Braintrust management roles access to S3 buckets owned outside the BYOC
  account, except the exact Braintrust deployment artifact bucket;
- restrict KMS grants to requests made by integrated AWS services; and
- deny shell, session, and role chaining paths.

`customer-retained-data-service-control-policy.json` protects the exact
resources preserved by the default `retain-data` workflow and independently
reinforces restrictions on human data and shell access:

- Brainstore bucket and objects;
- data plane KMS key and alias created by the module;
- matching final RDS snapshots;
- the operation records bucket and objects owned by the customer;
- bootstrap storage and key configuration and state deletion (except lock files);
- direct object, secret, database record, queue, and application log reads by
  human roles; and
- interactive access through SSM, ECS Exec, EKS, or EC2 Instance Connect.

Two documents keep each SCP comfortably below the AWS size limit and separate
the deployment and identity contract from human and retained data protections.

Replace every placeholder before use:

| Placeholder | Value |
| --- | --- |
| `<ACCOUNT_ID>` | Dedicated AWS account ID |
| `<AWS_REGION>` | Data plane AWS Region |
| `<BOOTSTRAP_NAME>` | Short identifier for this customer access contract |
| `<MANAGED_RESOURCE_PREFIX>` | Exact approved Terraform `deployment_name` prefix; enumerate multiple safe prefixes when needed |
| `<RUNTIME_BOUNDARY_ARN>` | ARN of the runtime boundary created by the customer |
| `<STATE_BUCKET_NAME>` | Terraform state bucket owned by the customer |
| `<OPERATION_LOG_BUCKET_NAME>` | Operation log bucket owned by the customer |
| `<BRAINTRUST_ARTIFACT_BUCKET_NAME>` | Exact Braintrust deployment artifact bucket for the data plane Region |
| `<BRAINSTORE_BUCKET_NAME>` | Exact Brainstore data bucket |
| `<DATA_PLANE_KMS_KEY_ARN>` | Exact KMS key retained with customer data |
| `<LICENSE_SECRET_KMS_KEY_ARN>` | Resolved license secret key ARN, including a key managed by AWS if used |
| `<STATE_KMS_KEY_ARN>` | State key owned by the customer, if used |
| `<OPERATION_LOG_KMS_KEY_ARN>` | Operation log key owned by the customer, if used |
| `<RETAINED_RDS_SNAPSHOT_PREFIX>` | Prefix for retained final RDS snapshots |
| `<LICENSE_SECRET_ARN>` | Exact ARN of the license secret owned by the customer |

Follow the optional key and S3 Bucket Key instructions in
[`../policies/README.md`](../policies/README.md). The examples target the `aws`
partition. Deploy SCPs as minified JSON: AWS CLI/API submissions count
whitespace against the [SCP size limit](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_reference_limits.html).

An SCP does not grant permissions. It limits the maximum permissions available
to identities in the account. An explicit deny overrides role policies and
permissions boundaries, including customer administrative roles inside the
member account when their principal matches a statement.

The deny for account and organization administration intentionally covers every
member account identity. Other statements apply only to matching principals.
SCPs do not constrain AWS service-linked roles; the deployment policy allows
creation only for listed services, and those roles do not receive the runtime
boundary. Review that exception when enabling a new service.

## External AWS access

The S3 owner-account deny applies to the three Braintrust management roles. It
checks `aws:ResourceAccount` only when AWS supplies it, so account-level S3 APIs
without a resource owner remain governed by their identity policies. The exact
artifact bucket is excluded because deployment must read it; the deployment
identity policy grants only read operations on that bucket. This is not a
universal cross-account deny for every AWS service.

The customer-owned runtime boundary denies all role assumption by default.
Before enabling an integration that assumes a role in another account, change
that statement to a deny using `NotResource` with only the exact approved role
ARNs. Also set the source workload's role allowlist to those ARNs and restrict
each destination role's trust and permissions to the intended workload. The
shared boundary exception is not specific to one workload, so the source
policy and destination trust remain essential. When no integration is enabled,
keep the default deny. The current Terraform module treats an empty
Bedrock or S3 export role allowlist as `Resource: "*"`; the boundary prevents
role assumption in this preview, but explicit source allowlists are required
before an integration is enabled.

Direct access to a customer-approved external resource, such as an existing S3
bucket or KMS key, needs an exact resource and owner-account review. The
customer's destination resource policy remains a separate gate. The S3 SCP
above covers management roles, not runtime identities; the runtime boundary
does not yet impose a universal resource-owner cap on direct API calls. New
AWS services may need service-specific controls because `aws:ResourceAccount`
is not available for every action. Record each enabled external path and review
its permissions and audit coverage when it changes.

Braintrust will validate the policies in a test account before production use.
Keep a recovery role controlled by the customer or a path through the management
account outside the Braintrust trust chain. Permanent erasure requires the
customer to remove or amend the SCP that protects retained data before using an
explicitly authorized erasure workflow.

The SCP that protects retained data does not deny Brainstore lifecycle updates
because the Terraform module manages that configuration during normal operation
and IAM cannot inspect the proposed lifecycle rules. Alert on every lifecycle
change and review it as a data disposition event.
