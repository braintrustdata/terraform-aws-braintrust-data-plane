# Customer service control policies

[Back to overview](../README.md#start-here)

The BYOC account must be an AWS Organizations member account with SCPs enabled,
not the organization's management account. [AWS documents these limits](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html).
The three SCPs are reference implementations for that dedicated account.
Customers can use equivalent existing organization controls if those controls
provide the same effective safeguards. Validate the combined controls before
production use; the JSON need not be copied exactly.

| Policy | Purpose |
| --- | --- |
| [customer-service-control-policy.json](customer-service-control-policy.json) | Access limits, runtime IAM controls, bootstrap protection, and audit safeguards |
| [customer-retained-data-service-control-policy.json](customer-retained-data-service-control-policy.json) | Retained storage and keys, routine human access limits, and deployment content and delegation restrictions |
| [customer-diagnostics-service-control-policy.json](customer-diagnostics-service-control-policy.json) | Diagnostic sessions and logging, plus workload and service-linked role safeguards |

All three are required, or must be replaced by validated equivalent organization
controls. Restrictions are distributed across them to stay within AWS policy size
limits; no file is a complete guardrail on its own. Identity policies and the runtime
boundary use positive allowances; these SCPs enforce the explicit denials.

An SCP sets permission limits; it does not grant access. An explicit deny overrides
role policies and permissions boundaries, including customer administrative roles
inside the member account when their principal matches a statement.

## Access safeguards

The access SCP:

- requires the runtime boundary owned by the customer when deployment automation
  creates a role;
- constrains role creation and `PassRole` to the configured resource prefix;
- prevents bootstrap IAM changes except attaching or detaching the three
  predefined policies on the exact Diagnostics role, while allowing metadata
  reads for verification;
- prevents Braintrust roles from disabling customer audit controls;
- prevents account identities from changing or removing account-level S3 Block
  Public Access;
- prevents deployment automation from routing or exporting application logs;
- denies direct application object and secret reads outside documented machine
  exceptions, and caps KMS decryption by key identity or managed tag, service,
  and encryption context;
- denies Braintrust management roles access to S3 buckets owned outside the BYOC
  account, except the exact Braintrust deployment artifact bucket;
- restricts KMS grants to requests made by integrated AWS services; and
- denies deployment shell, session, and role chaining paths.

## Retained data and routine human access

The retained data SCP protects the resources preserved by the default `retain-data`
workflow and independently reinforces restrictions on Support and Observer access:

- Brainstore buckets named by the module and their objects across data planes;
- all KMS keys in the configured account and Region against disablement or
  scheduled deletion by Deployment, plus aliases named by the module and
  protection of the managed key ownership tag;
- matching final RDS snapshots;
- the operation records bucket and objects owned by the customer;
- bootstrap storage and key configuration and state deletion (except lock files);
- direct object, secret, database record, queue, and application log reads by
  Support and Observer, including samples and reports derived from logs;
- deployment access to application logs, general workload invocation, export and
  sharing APIs, and samples or reports derived from logs;
- deployment `PassRole` service limits and administrator policy attachment; and
- interactive SSM, ECS Exec, and EC2 Instance Connect access by those two roles,
  outbound role assumption, and access through the EKS console viewer.
  Kubernetes RBAC is separate.

## Diagnostics safeguards

The Diagnostics SCP also protects delegated workloads:

- denies runtime access to bootstrap storage and IAM, plus changes to key
  administration and bucket access controls; audit protection is shared through
  the access SCP;
- prevents runtime initiation of shell or execution paths and limits role
  assumptions to the intended API handler's internal invocation targets;
- restricts deployment service-linked role creation to the listed services and
  their AWS IAM path;
- protects the logged SSM shell document and diagnostic transcript configuration
  from both Braintrust management and matching runtime roles;
- denies management roles direct transcript stream creation and event writes,
  while preserving delivery by instance and task roles;
- denies `ecs:UpdateCluster` to Support, Observer, Diagnostics, and matching runtime
  roles, while preserving Deployment's cluster management;
- retains Diagnostics restrictions on identity administration, direct state and
  data APIs, alternative SSM documents, generic Run Command, and EC2 Instance Connect.

We use logged Session Manager shells and ECS Exec, not SSH or port forwarding
sessions. The diagnostic policy's positive grants further constrain the targets.
Deployment can change ECS Exec logging, so activation checks and monitoring are
required. Protected destinations also do not prevent a privileged shell from
affecting capture; see the [Diagnostics guide](../diagnostics.md).

Runtime access can still modify data through the application: restrictions
protecting retained data from human AWS principals do not make a privileged
shell read-only.

## Scope and implementation

Use the [shared placeholder definitions](../policies/README.md#placeholders) and
[mandatory IAM paths](../policies/README.md#naming-and-scope). Follow the same guide
for optional encryption keys and S3 Bucket Keys. A role outside
the protected `/braintrust-byoc/` path will not match the selectors for
management roles.
The examples target one configured Region in the `aws`
partition. Deploy SCPs as minified JSON: AWS CLI/API submissions count
whitespace against the [SCP size limit](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_reference_limits.html).

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

For collection requirements and alert signals, see the
[monitoring guide](cloudtrail-alerting.md).
