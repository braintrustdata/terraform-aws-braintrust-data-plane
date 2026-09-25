# Customer service control policies

The two SCPs are reference implementations for the dedicated AWS account.
Customers can use equivalent existing organization controls if those controls
provide the same effective safeguards. Validate the combined controls before
production use; the JSON need not be copied byte-for-byte.

`customer-service-control-policy.json` protects the access model. Its
main controls are:

- require the runtime boundary owned by the customer when deployment automation
  creates a role;
- constrain role creation and `PassRole` to the configured resource prefix;
- prevent the deployment role from editing bootstrap roles and policies;
- prevent Braintrust roles from disabling customer audit controls;
- prevent deployment automation from routing or exporting application logs;
- deny direct application object and secret reads outside documented machine
  exceptions, and cap KMS decryption by key identity or managed tag, service,
  and encryption context;
- deny Braintrust management roles access to S3 buckets owned outside the BYOC
  account, except the exact Braintrust deployment artifact bucket;
- restrict KMS grants to requests made by integrated AWS services; and
- deny shell, session, and role chaining paths.

`customer-retained-data-service-control-policy.json` protects the exact
resources preserved by the default `retain-data` workflow and independently
reinforces restrictions on human data and shell access:

- module-named Brainstore buckets and objects across data planes;
- all KMS keys in the dedicated account against deployment-role disablement or
  scheduled deletion, plus module-named aliases;
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
| `<MANAGED_RESOURCE_PREFIX>` | Reserved, non-overlapping prefix for every `deployment_name` under this bootstrap |
| `<RUNTIME_BOUNDARY_ARN>` | ARN of the runtime boundary created by the customer |
| `<STATE_BUCKET_NAME>` | Terraform state bucket owned by the customer |
| `<OPERATION_LOG_BUCKET_NAME>` | Operation log bucket owned by the customer |
| `<BRAINTRUST_ARTIFACT_BUCKET_NAME>` | Exact Braintrust deployment artifact bucket for the data plane Region |
| `<LICENSE_SECRET_KMS_KEY_ARN>` | Resolved license secret key ARN, including a key managed by AWS if used |
| `<STATE_KMS_KEY_ARN>` | State key owned by the customer, if used |
| `<OPERATION_LOG_KMS_KEY_ARN>` | Operation log key owned by the customer, if used |
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
boundary. Account for that exception when enabling a new service.

## External AWS access

The S3 guardrail restricts Braintrust's Deployment, Support, and Observer roles
from accessing buckets owned outside the BYOC account, except the named
Braintrust software bucket needed for deployment. It applies when AWS supplies
the bucket owner's account; identity policies govern other S3 requests.

Runtime role assumption is denied by default. A feature such as Bedrock access
or S3 export can use an external role or resource only with its documented
destination and permissions, a matching workload policy, and the required
destination-side controls. The [policy guide](../policies/README.md#external-feature-policy-notes)
explains the implementation limits.
