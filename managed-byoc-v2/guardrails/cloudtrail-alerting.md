# AWS security monitoring

[Back to overview](../README.md#start-here)

Use the customer's existing CloudTrail and security monitoring where available.
Braintrust operates the data plane; the customer controls organization safeguards,
audit collection, alerts, and recovery access outside Braintrust's trust chain.

## Collection

- Collect read and write management events across deployed Regions.
  An organization trail delivered to a separate audit account is recommended.
- Enable targeted data events where a detection needs them, including object
  access to state/operation buckets and unexpected management-role access to
  application storage. S3 object reads, Lambda invocations, and message/record
  access are not covered by management events alone.
- Scope selectors before ingestion. Do not enable all workload data events
  unless needed for a detection or compliance requirement; volume can be high.
- For enabled external integrations, collect the destination role's activity
  and relevant data events in that account too.
- Preserve role ARN, session name, SourceIdentity, event ID/time, source IP,
  request parameters, result, and error code. Evaluate successful and denied
  requests; services use different denial codes and logging paths.
- Preserve the verified IAM Identity Center UserId and identity-store context
  where the login and STS event schemas expose them. Diagnostics SourceIdentity
  and target role-session name must match that verified individual identity.

CloudTrail captures supported activity selected by that configuration, not every
API call. Validate the required allowed and denied events before relying on alerts.
Existing GuardDuty, Config, Security Hub, and Access Analyzer coverage can
complement these detections; a new monitoring stack is not required.

## Recommended detections

Scope signals to the BYOC account, bootstrap resources, and named roles.
An API name alone is not evidence of an unsafe change; inspect request parameters.

| Priority | Signal | Evaluate |
| --- | --- | --- |
| High | Bootstrap IAM or organization safeguards changed | Trust, inline policies, policy versions/defaults, boundaries, attachments, and SCP changes; match Diagnostics trust updates to recorded participants and deadlines |
| High | Logging or security collection weakened | Trail/event selector changes; Config, GuardDuty, Security Hub, or Access Analyzer changes; logged SSM document or transcript-group configuration changes |
| High | Unexpected interactive access | Wrong role/target, missing attribution, or a role session not issued under a valid named Diagnostics grant; generic Run Command or Instance Connect use |
| High | Unexpected Diagnostics trust or permissions | Unrecorded principal, participant, deadline, or extension; missing identity/deadline conditions; altered fixed policies or customer-disable deny; failed trust restoration or missing transcripts |
| High | Retained data affected | Brainstore lifecycle expiration, bucket/object deletion, KMS disablement/deletion, final snapshot deletion, and snapshot sharing/export |
| High | Public or unexpected external access | Account/bucket protection changes, broadened bucket/key/runtime trust, public network changes, or runtime role assumption outside a configured feature |
| High | Unexpected content access or log routing | Observer content reads; management-role subscription filters, export tasks, deliveries, or content-derived reports outside its permissions |
| Audit | Deployment and Diagnostics activity | Role assumptions, operation attribution, activation/extension/closure evidence, session targets, and operational mutations |

The SCP blocks only its listed actions. A successful sensitive API does not
necessarily mean the SCP was detached: lifecycle expiration and some security
configuration updates are outside its coverage.

For Diagnostics, correlate `UpdateAssumeRolePolicy` and successful `AssumeRole`
events with the exact role, source principal, verified UserId, matching
SourceIdentity and session name, bootstrap, approval, and recorded times.
Watch customer changes to `DiagnosticsActivationEnabled` and verify the resulting
trust and protected inline policy. Policy attachments do not change during
activation; do not treat them as expected window activity. Access after the trust
deadline can come from credentials issued during the window, so evaluate their
issue/expiry times and native session limits before treating it as unauthorized.
An expired grant does not authorize a new role assumption. Early trust changes
take time to propagate beyond readback; distinguish that interval from the
unchanged grant's absolute deadline.

Operational checks include ECS task definitions/network changes, ASG desired
capacity and health, scaling limits, Lambda concurrency, paused module schedules,
and database/cache tuning. Alert on ECS cluster Exec logging departing from
`OVERRIDE` or changing destination, not every normal cluster update.
CloudTrail event names can differ from IAM actions, including versioned Lambda
events; verify the service's actual events.

## Logging destinations

```mermaid
flowchart TB
    subgraph BT[Braintrust]
        DEP[BYOC deployment service]
        ENG[Named support personnel]
    end

    subgraph CUSTOMER[Customer AWS environment]
        subgraph BYOC[BYOC account]
            API["AWS APIs<br/>Trust updates, assumptions, infrastructure"]
            SSM["SSM shell on EC2<br/>Logged session document"]
            ECS["ECS Exec<br/>OVERRIDE transcript logging"]
            CW["CloudWatch log group<br/>Diagnostic transcripts"]
            OPS[("S3 operation records")]
        end
        subgraph ARCHIVE["Separate audit account (recommended)"]
            CT[("Organization CloudTrail archive")]
            COPY["Copied diagnostic transcripts"]
        end
    end

    DEP -->|deployment and timed trust updates| API
    ENG -->|attributed sessions| API
    API -->|StartSession| SSM
    API -->|ExecuteCommand| ECS
    API -.->|configured API events, not commands| CT
    SSM -->|commands and output| CW
    ECS -->|commands and output| CW
    CW -.->|optional customer replication| COPY
    DEP -->|intent, authorization, outcome| OPS
```

SSM and ECS Exec write to
`/braintrust-byoc/<BOOTSTRAP_NAME>/diagnostics` in the BYOC account, using
default CloudWatch encryption and 90-day retention. Braintrust's bootstrap
and module configure collection; customers do not need to build this destination.
We use standard SSM shells, not SSH or port forwarding.

CloudTrail is the API audit trail, not the shell transcript. Operation records
describe participants, authorization, expiry, trust changes, and outcomes; they
are not transcripts either.
A privileged shell can interfere with capture. Customer-controlled
[CloudWatch Logs centralization](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CloudWatchLogs_Centralization.html)
to a separate archive preserves delivered evidence, but cannot prevent missing
capture at the source.

## Detection implementation

Use the customer's SIEM, EventBridge, or existing alerting pipeline.
The example below uses CloudWatch Logs filter syntax and requires trail delivery
to CloudWatch; it is an optional starting point, not a required implementation.

```text
{ ($.userIdentity.sessionContext.sessionIssuer.userName = "Braintrust*Role-*") && (($.eventName = "StartSession") || ($.eventName = "ExecuteCommand") || ($.eventName = "SendCommand")) }
```

This filter identifies candidate events, not whether access was authorized.
Correlate SourceIdentity, exact target, and the recorded window. Match the exact
bootstrap when implementing a deployment-specific rule. Test delivery and
detection with safe requests before relying on it.

On unexplained activity, preserve evidence, block new assumptions, revoke issued
sessions, and terminate active connections using independent customer access.
Coordinate recovery with Braintrust; lasting configuration changes go through
the deployment workflow. See [customer revocation](../diagnostics.md#customer-revocation).

References: [CloudTrail event coverage](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-events.html),
[data events](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-data-events-with-cloudtrail.html),
[filter syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html).
