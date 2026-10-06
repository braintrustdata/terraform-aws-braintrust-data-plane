# Protected Diagnostics transcripts

Set `diagnostics_transcript_log_group_name` to an existing, bootstrap-owned
CloudWatch log group in the deployment account and region. This optional input
selects ECS Exec `OVERRIDE` logging and gives enabled EC2/task roles delivery
permissions to that group only. It does not create, retain, or delete the group.
Null preserves previous cluster logging and creates no transcript policies.

Enable Brainstore SSM and the desired ECS services independently using
`enable_brainstore_ec2_ssm`, `api_ecs_enable_execute_command`,
`ai_gateway_enable_execute_command`, and `loop_runtime_enable_execute_command`.
New ECS tasks are required when enabling Exec on an existing service.

The shared API/Lambda role receives transcript-delivery permissions only when
API ECS exists and `api_ecs_enable_execute_command` is enabled. Selecting a
destination for Brainstore, Gateway, or Loop does not grant API transcript writes.
Existing ECS task trust and non-transcript permissions remain unchanged.

The customer bootstrap owns the protected Session Manager shell document, its
CloudWatch streaming settings, the transcript group, and human access policies.
The module does not accept a shell-document input because it does not initiate
human sessions. It does not grant humans Diagnostics access or manage its
activation window.

Before activation, verify the approved SSM document and destination, workload
delivery permissions, agent/network readiness, and ECS task Exec readiness.
ECS images must contain `script` and `cat`; infrastructure configuration alone
does not establish successful transcript delivery.

ECS Exec `kms_key_id` encrypts session traffic; transcript storage uses the log
group's encryption. CloudWatch Logs always encrypts data at rest. The module sets
`cloud_watch_encryption_enabled = false`: it does not require customer-managed
KMS encryption or disable an existing log-group key. Setting this flag to `true`
requires an existing customer-managed KMS-encrypted group; it does not configure
the group's encryption. See [ECS Exec logging](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html#ecs-exec-logging)
and [CloudWatch encryption](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html).

Upgrades without this optional input preserve existing resource addresses and
permission defaults. Adopting the input changes the cluster logging destination
and adds scoped inline policies; it does not move Terraform state or replace
workload roles. Test delivery using representative EC2 and ECS sessions before
allowing production Diagnostics activation.
