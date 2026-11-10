# Customer service control policy

[Back to overview](../README.md#start-here)

[customer-service-control-policy.json](customer-service-control-policy.json)
is the recommended organization baseline for the dedicated BYOC account.
It is identical across customer bootstraps, with no placeholders or principal
exceptions. It protects selected account safeguards, not a second copy of each
role's IAM permissions.

## Prerequisites and administration

- Use an AWS Organizations member account with SCPs enabled, not the management
  account.
- Enable all four account-level S3 Block Public Access settings before attaching
  the policy. The SCP protects the configuration; it does not enable it.
- Apply the minified policy, or validated equivalent organization controls,
  through the customer's normal deployment process. Braintrust does not attach it.

The policy constrains member-account principals, including customer
administrators and root. AWS service-linked roles and management-account
principals are outside its scope. Protected maintenance requires an organization
administrator to amend the policy and restore the baseline. Keep that
administrative recovery path independent of Braintrust.

## Protections

| Statement | Blocks |
| --- | --- |
| `ProtectOrganizationMembership` | Leaving the AWS organization |
| `ProtectAccountPublicAccessBlock` | Changing or removing account-level S3 public access protection |
| `ProtectSecurityServices` | Listed deletion, stop, and disassociation actions for CloudTrail, Config, GuardDuty, Security Hub, and Access Analyzer |
| `ProtectRetainedData` | Scheduling any KMS key deletion, deleting module-pattern final RDS snapshots, and deleting Brainstore-pattern buckets |
| `DenySnapshotAndImageSharing` | Changing AMI, EBS snapshot, and RDS snapshot sharing attributes |

The bucket and snapshot patterns match the module's resource names across
Regions and bootstraps. The KMS deletion protection covers every key in the
member account, not only module-tagged keys.

These are specific API restrictions, not complete data-loss or audit-integrity
guarantees. Object deletion, lifecycle expiration, and security-service updates
that weaken collection are not comprehensively blocked. IAM, resource policies,
operational checks, and monitoring still matter.

## Where the other controls live

| Control | Enforcement |
| --- | --- |
| Role capabilities and exact Diagnostics trust-update target | [Identity policies](../policies/README.md#role-attachment-model) |
| Customer Diagnostics disable control | Bootstrap-owned inline deny on Deployment and disabled Diagnostics trust |
| Owning bootstrap stack protection | Deployment explicit deny using the actual CloudFormation StackId |
| Runtime IAM prefix, required boundary, and permitted `PassRole` services | Deployment policy resources and conditions |
| Workload permissions, excluding bootstrap storage | Module policies intersected with the runtime boundary |
| Deployment log management excluding diagnostic transcripts | Deployment workload policy resource exclusions |
| Bucket, key, and external integration access | Scoped IAM and resource/key policies |

Deployment remains able to change workload code, managed runtime trust, and the
exact Diagnostics trust when the activation capability and customer control
permit it. The SCP does not enforce Diagnostics participant lists or deadlines,
or provide an independent customer approval gate. The bootstrap disable control
restricts Deployment directly; review privileged indirect delegation as described
in [Diagnostics](../diagnostics.md#customer-owned-disable-control). Customer
monitoring and [revocation](../diagnostics.md#customer-revocation) remain part of
the model.

See [monitoring](cloudtrail-alerting.md),
[AWS SCP scope](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html),
and [policy limits](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_reference_limits.html).
