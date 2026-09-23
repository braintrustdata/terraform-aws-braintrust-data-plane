# CloudTrail alerting MVP

These controls define the minimum detection baseline for the dedicated BYOC
account. The customer owns and operates them. They complement IAM, permissions
boundaries, and SCPs; they do not prevent an action that is otherwise authorized.

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
- For an enabled integration into another customer-owned account, collect
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
| Critical | Bootstrap identity or guardrail change | `UpdateAssumeRolePolicy`, `AttachRolePolicy`, `DetachRolePolicy`, `PutRolePolicy`, `DeleteRolePolicy`, `PutRolePermissionsBoundary`, `DeleteRolePermissionsBoundary`, `CreatePolicyVersion`, `SetDefaultPolicyVersion`, or relevant Organizations policy changes targeting the BYOC roles, boundaries, or SCPs |
| Critical | Audit or security control tampering | `StopLogging`, `DeleteTrail`, `PutEventSelectors`, `UpdateTrail`, `StopConfigurationRecorder`, configuration recorder or delivery channel deletion, GuardDuty disable/delete/disassociation, Security Hub disable/disassociation, or Access Analyzer deletion |
| Critical | Human access to protected content | A Support or Observer session calls S3 `GetObject*`, Secrets Manager `GetSecretValue`, KMS `Decrypt`, DynamoDB read APIs, SQS `ReceiveMessage`, RDS log download APIs, or Lambda invocation APIs, whether allowed or denied |
| Critical | Retained data disposition | `DeleteBucket`, `DeleteObject*`, `PutBucketLifecycleConfiguration`, `ScheduleKeyDeletion`, `DisableKey`, `DeleteDBSnapshot`, snapshot sharing/export, or an unexpected `DeleteDBInstance` against a protected resource |
| Critical | Interactive access | `StartSession`, `SendCommand`, `ExecuteCommand`, `SendSSHPublicKey`, `OpenTunnel`, or `AccessKubernetesApi` by a Braintrust principal |
| Critical | Public exposure | Security group ingress changes, S3 public access or bucket policy changes, an ECS update requesting public IP assignment, or an RDS update requesting public accessibility |
| High | Unexpected Support activity | A Support mutation has an unexpected source identity, target data plane, or request parameters |
| High | Unexpected deployment session | Deployment role assumption or mutation has an unexpected source principal or a missing or malformed operation source identity |
| High | Unexpected external access | A Braintrust role assumes a destination role or accesses an external resource outside an enabled feature's documented access, whether allowed or denied; correlate expected runtime assumptions with destination-account activity |
| High | Sensitive authorization failure | `AccessDenied`, `UnauthorizedOperation`, or equivalent from a Braintrust principal for IAM, STS, S3 object, Secrets Manager, KMS, interactive access, retained data, or audit control APIs |
| Audit | Human role assumption | Every successful and failed `AssumeRole` attempt for Support and Observer; notify according to the customer's operating model |
| Audit | Support mutation | Every successful event in the Support mutation set below; preserve it in the customer audit archive |

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

- `UpdateService`: task definition, network configuration, public IP,
  load balancer changes, and ECS Exec enablement.
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
- `CreateGrant`: unexpected grantees, operations, or absence of a matching
  service provisioning operation. A grant created by an AWS service is expected;
  arbitrary direct grant creation is not.
- `AssumeRole` by a runtime identity: source workload role, exact destination
  role ARN and account, enabled integration, and activity under the resulting
  destination session.
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
record of commands inside a shell; interactive access is excluded by this model.
