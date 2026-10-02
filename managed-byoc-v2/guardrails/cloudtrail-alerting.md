# CloudTrail monitoring and alerts

[Back to overview](../README.md#start-here)

These controls define the minimum detection baseline for the dedicated BYOC
account. The customer owns and operates them. They complement the
[IAM policies](../policies/README.md) and [guardrails](README.md); they do not
prevent an action that is otherwise authorized.

## Collection prerequisites

- Use a multi-Region organization trail and send it to a customer log archive
  account that Braintrust roles cannot access or modify.
- Record read and write management events.
- Enable S3 data events for the exact Brainstore, Terraform state, and operation
  log buckets. S3 object reads and writes are not management
  events and are absent without this configuration.
- Add data event selectors for deployed Lambda functions (`AWS::Lambda::Function`),
  DynamoDB tables (`AWS::DynamoDB::Table`), and SQS queues (`AWS::SQS::Queue`).
  Use advanced selectors for SQS. Select the read/write categories needed for
  invocation and record/message reads; management events alone do not cover them.
- For an enabled integration into another account owned by the customer, collect
  CloudTrail there as well. Include the destination role's activity and data
  events for any bucket or other supported resource used by the integration.
- Send alerts to an EventBridge bus, SIEM, or security operations destination
  controlled by the customer and outside the Braintrust trust chain.
- Retain the role ARN, session name, source identity, source IP, user agent,
  event ID, request parameters, response elements, and error code. Correlate
  session tags from STS events where available; they are not repeated on every
  service event.
- Evaluate successful calls and authorization failures. A denied sensitive
  action can indicate a compromised or incorrectly configured session.

## Alert matrix

| Severity | Signal | Events or evaluation |
| --- | --- | --- |
| Critical | Bootstrap identity or guardrail change, excluding the three recorded Diagnostics activation pairs below | `UpdateAssumeRolePolicy`, `AttachRolePolicy`, `DetachRolePolicy`, `PutRolePolicy`, `DeleteRolePolicy`, `PutRolePermissionsBoundary`, `DeleteRolePermissionsBoundary`, `CreatePolicyVersion`, `SetDefaultPolicyVersion`, or relevant Organizations policy changes targeting the BYOC roles, boundaries, or SCPs |
| Critical | Audit or security control tampering | `StopLogging`, `DeleteTrail`, `PutEventSelectors`, `UpdateTrail`, `StopConfigurationRecorder`, configuration recorder or delivery channel deletion, GuardDuty disable/delete/disassociation, Security Hub disable/disassociation, or Access Analyzer deletion |
| Critical | Human access to protected content | A Support or Observer session calls S3 `GetObject*`, Secrets Manager `GetSecretValue`, KMS `Decrypt`, DynamoDB read APIs, SQS `ReceiveMessage`, RDS log download APIs, or Lambda invocation APIs, whether allowed or denied |
| Critical | Retained data disposition | `DeleteBucket`, `DeleteObject*`, `PutBucketLifecycleConfiguration`, `ScheduleKeyDeletion`, `DisableKey`, `DeleteDBSnapshot`, snapshot sharing/export, or an unexpected `DeleteDBInstance` against a protected resource |
| Critical | Application log export or routing | Deployment calls `CreateExportTask`, `PutSubscriptionFilter`, `CreateDelivery`, `PutDelivery*`, `PutDestination*`, or `PutAccountPolicy`, including denied attempts |
| Critical | Access to content derived from logs | Deployment, Support, or Observer attempts `PutInsightRule`, `PutManagedInsightRules`, `GetInsightRuleReport`, `CreateLogAnomalyDetector`, `ListAnomalies`, or `GetLookupTable`; collect supported events for these APIs |
| Critical | Unexpected interactive access | `StartSession` or `ExecuteCommand` outside an active Diagnostics window, from another role, or against another bootstrap; any `SendCommand`, `SendSSHPublicKey`, or `OpenTunnel` by a Braintrust management role |
| Critical | Public exposure | Security group ingress changes, S3 public access or bucket policy changes, an ECS update requesting public IP assignment, or an RDS update requesting public accessibility |
| High | Unexpected Support activity | A Support mutation has an unexpected source identity, target data plane, or request parameters |
| High | Unexpected deployment session | Deployment role assumption or mutation has an unexpected source principal or a missing or malformed operation source identity |
| High | Unexpected role assumption or external access | Any outbound `AssumeRole` by Deployment, Support, Observer, or Diagnostics; a runtime assumption outside its internal invocation paths or an enabled feature's exact destination; unexpected external resource access |
| High | Unexpected runtime role trust | `CreateRole` or `UpdateAssumeRolePolicy` admits an unexpected human, account, or service principal into a managed runtime role |
| High | Sensitive authorization failure | `AccessDenied`, `UnauthorizedOperation`, or equivalent from a Braintrust principal for IAM, STS, S3 object, Secrets Manager, KMS, interactive access, retained data, or audit control APIs |
| High | KMS ownership tag change | `TagResource` or `UntagResource` affecting `BraintrustDeploymentName`, other than the expected tag on key creation |
| Audit | Human role assumption | Every successful and failed `AssumeRole` attempt for Support, Observer, and Diagnostics; notify according to the customer's operating model |
| Audit | Support mutation | Every successful event in the Support mutation set below; preserve it in the customer audit archive |
| Audit | Diagnostics activation and closure | Three exact role/policy `AttachRolePolicy` / `DetachRolePolicy` pairs, actor, reason, scope, expiry, and cleanup result from operation records; escalate unmatched or overdue activity |
| Audit | Diagnostic session | `StartSession`, `ResumeSession`, `TerminateSession`, and `ExecuteCommand`; correlate named role session, target, activation, and CloudWatch transcript |
| Critical | Diagnostic logging changes | Protected SSM document updates/deletion, transcript group deletion or retention/configuration changes, and ECS Exec configuration changes, including denied attempts |

## Support mutation set

The standing Support policy currently authorizes this event set:

- ECS: `UpdateService`, `StopTask`, `StopServiceDeployment`
- EC2 Auto Scaling: `SetDesiredCapacity`, `SetInstanceHealth`, `CancelInstanceRefresh`
- Application Auto Scaling: `RegisterScalableTarget`, `PutScalingPolicy`
- Lambda: `PutFunctionConcurrency20171031`, `DeleteFunctionConcurrency20171031`,
  `PutProvisionedConcurrencyConfig`, `DeleteProvisionedConcurrencyConfig`
- EventBridge: `DisableRule`, `EnableRule` for the module's three scheduled jobs
- RDS: `RebootDBInstance`, `ModifyDBParameterGroup`
- ElastiCache: `RebootCacheCluster`

Lambda CloudTrail event names can include API version suffixes; match the
[documented event names](https://docs.aws.amazon.com/lambda/latest/dg/logging-using-cloudtrail.html)
rather than assuming they always equal IAM action names.

These events should normally create an audit notification rather than a page.
Raise them to High for unexpected session attribution, target scope, or request
parameters. Routine maintenance does not require an incident ID or fixed window.

## Important request checks

Event names alone are insufficient for APIs that accept both safe and unsafe
changes. Inspect request parameters where available:

- Diagnostics `AttachRolePolicy` / `DetachRolePolicy`: exact role and one of the
  three predefined policy ARNs, deployment principal, operation source identity,
  authorization, and expiry. Activation and cleanup must account for all three
  attachments; flag partial or unexpected attachment sets. Do not exclude all
  policy attachments from alerts for identity changes.
- `StartSession`: exact logged document, matching Brainstore target, and engineer
  identity. `ExecuteCommand`: matching cluster, task, and container. Compare both
  with the active window for the bootstrap.
- `TerminateSession`: expected diagnostic ownership and cleanup result. Alert
  when sessions remain after closure, transcripts are missing, or cleanup fails.
- `UpdateService`: task definition, network configuration, public IP,
  load balancer changes, and ECS Exec enablement.
- `CreateCluster` / `UpdateCluster` (deployment only): ECS Exec logging must
  remain `OVERRIDE` to the protected diagnostic group. Alert on unexpected mode,
  destination, or encryption changes, not ordinary cluster setting updates.
- `StopServiceDeployment`: target service/deployment, stop type, and the previous
  revision restored by rollback.
- `SetDesiredCapacity`, `SetInstanceHealth`, `CancelInstanceRefresh`: target group,
  requested capacity, instance health transition, or interrupted rollout.
- `RegisterScalableTarget`, `PutScalingPolicy`: cluster/service resource ID,
  minimum/maximum capacity, suspended scaling, target values, and cooldowns.
- Lambda concurrency changes: function, alias/version, requested capacity, zero
  concurrency, and removal of limits. Consider the shared regional capacity pool.
- `DisableRule`, `EnableRule`: exact job and whether it remains disabled longer
  than intended.
- `UpdateAutoScalingGroup` (deployment only): launch template/configuration,
  instance types, subnets, and minimum/maximum capacity.
- `ModifyDBInstance` (deployment only): master credential management, public
  accessibility, security groups, deletion protection, and other connectivity changes.
- `PutBucketLifecycleConfiguration`: any new or shortened current version or
  noncurrent version expiration.
- `PutBucketPolicy` and `PutKeyPolicy`: new external principals, wildcard
  principals, or loss of the customer recovery principal.
- Runtime `CreateRole` and `UpdateAssumeRolePolicy`: expected AWS service or
  exact internal invocation principal, plus trust required by enabled features. Flag
  unexpected human principals, accounts, or broadened trust conditions.
- `CreateGrant`: unexpected grantees, operations, or absence of a matching
  service provisioning operation. A grant created by an AWS service is expected;
  arbitrary direct grant creation is not.
- `AssumeRole` by a runtime identity: source workload role, exact destination
  role ARN and account, internal invocation path or enabled integration, and
  activity under the resulting destination session. Internal quarantine and
  AI Proxy invocation should originate from the API handler for that data plane.
- Security control update APIs: disabling a GuardDuty detector, narrowing Config
  recording, disabling Security Hub controls, changing CloudTrail collection, or
  adding an Access Analyzer archive rule can weaken detection without deletion.

## Response expectations

1. Preserve the event and surrounding session activity in the customer archive.
2. Stop new sessions and revoke existing sessions for the affected Braintrust
   role if activity is unexplained or ongoing.
3. Determine whether protected data, credentials, networking, or retention was
   affected.
4. Coordinate with Braintrust to restore intended configuration through the
   deployment workflow.
5. Braintrust reconciles lasting Support changes into Terraform and records the
   outcome.

See AWS documentation for [CloudTrail event types](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-events.html)
and [CloudTrail data events](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html).

Verify delivery using both allowed and denied test requests. CloudTrail coverage
varies by service and rejection path; an alert rule is not evidence that every
denied request will produce an event. CloudTrail is an API audit trail, not a
record of commands inside a shell. The bootstrap/module must configure the
diagnostic CloudWatch log group in the customer account and session logging;
customers do not need to build that destination themselves. This model uses
logged Session Manager shells and ECS Exec, not SSH or port forwarding sessions.
Kubernetes API auditing and session handling are separate future implementation work.
