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
does not establish successful transcript delivery. Session encryption retains
the existing deployment KMS configuration; transcript storage uses the group's
encryption configuration.

Upgrades without this optional input preserve existing resource addresses and
permission defaults. Adopting the input changes the cluster logging destination
and adds scoped inline policies; it does not move Terraform state or replace
workload roles. Test delivery using representative EC2 and ECS sessions before
allowing production Diagnostics activation.
