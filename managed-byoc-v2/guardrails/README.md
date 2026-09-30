# Customer service control policies

The three SCPs are reference implementations for the dedicated AWS account.
Customers can use equivalent existing organization controls if those controls
provide the same effective safeguards. Validate the combined controls before
production use; the JSON need not be copied exactly.

`customer-service-control-policy.json` protects the access model. Its
main controls are:

- require the runtime boundary owned by the customer when deployment automation
  creates a role;
- constrain role creation and `PassRole` to the configured resource prefix;
- prevent bootstrap IAM changes except the exact Diagnostics role/policy
  attachment pair, while allowing metadata reads for verification;
- prevent Braintrust roles from disabling customer audit controls;
- prevent account identities from changing or removing account-level S3 Block
  Public Access;
- prevent deployment automation from routing or exporting application logs;
- deny direct application object and secret reads outside documented machine
  exceptions, and cap KMS decryption by key identity or managed tag, service,
  and encryption context;
- deny Braintrust management roles access to S3 buckets owned outside the BYOC
  account, except the exact Braintrust deployment artifact bucket;
- restrict KMS grants to requests made by integrated AWS services; and
- deny deployment shell, session, and role chaining paths.

`customer-retained-data-service-control-policy.json` protects the exact
resources preserved by the default `retain-data` workflow and independently
reinforces restrictions on routine Support and Observer data and shell access:

- Brainstore buckets named by the module and their objects across data planes;
- all KMS keys in the configured account and Region against disablement or
  scheduled deletion by Deployment, plus aliases named by the module;
- matching final RDS snapshots;
- the operation records bucket and objects owned by the customer;
- bootstrap storage and key configuration and state deletion (except lock files);
- direct object, secret, database record, queue, and application log reads by
  Support and Observer, including samples and reports derived from logs;
- deployment access to samples and reports derived from logs; and
- interactive SSM, ECS Exec, and EC2 Instance Connect access by those two roles,
  outbound role assumption, and access through the EKS console viewer.
  Kubernetes RBAC is separate.

`customer-diagnostics-service-control-policy.json` adds the troubleshooting
safeguards:

- protect the logged SSM shell document and diagnostic transcript configuration
  from both Braintrust management and matching runtime roles;
- deny management roles direct transcript stream creation and event writes,
  while preserving delivery by instance and task roles;
- deny `ecs:UpdateCluster` to Support, Observer, Diagnostics, and matching runtime
  roles, while preserving Deployment's cluster management;
- retain Diagnostics restrictions on identity administration, direct state and
  data APIs, alternative SSM documents, generic Run Command, and EC2 Instance Connect.

We use logged Session Manager shells and ECS Exec, not SSH or port forwarding
sessions. The diagnostic policy's positive grants further constrain the targets.
Deployment can change ECS Exec logging, so activation checks and monitoring are
required. Protected destinations also do not prevent a privileged shell from
affecting capture; see the [Diagnostics guide](../diagnostics.md).

Three documents separate identity, retained data, and diagnostic safeguards
while remaining within AWS policy size limits. All three apply to the baseline.
Runtime access can still modify data through the application: restrictions
protecting retained data from human AWS principals do not make a privileged
shell read-only.

Use the [shared placeholder definitions and mandatory IAM paths](../policies/README.md),
including its instructions for optional keys and S3 Bucket Keys. A role outside
the protected `/braintrust-byoc/` path will not match the selectors for
management roles.
The examples target one configured Region in the `aws`
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

## S3 public access protection

Before applying the SCP, enable account-level **Block all public access** (all
four settings). The SCP denies `s3:PutAccountPublicAccessBlock`, which AWS uses
for both changes and removal; it protects the existing configuration rather than
enabling it. Equivalent organization enforcement can provide the same safeguard.

Deployment can still manage private bucket policies and bucket-level settings.
Authorized presigned URLs remain supported: they use the signer's object
permissions, not anonymous public access. See [AWS's presigned URL guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html).

## External AWS access

The S3 guardrail restricts all four Braintrust management roles
from accessing buckets owned outside the BYOC account, except the named
Braintrust software bucket needed for deployment. It applies when AWS supplies
the bucket owner's account; identity policies govern other S3 requests.

Runtime role assumption is limited to the API handler's internal quarantine and
AI Proxy invocation paths. A feature such as Bedrock access
or S3 export can use an external role or resource only with its documented
destination and permissions, a matching workload policy, and the required
controls at the destination. The [policy guide](../policies/README.md#external-feature-policy-notes)
explains the implementation limits.
