# Trust policy reference

[Back to overview](../README.md#start-here)

[Deployment trust](deployment-role-trust-policy.json) is for automation.
[Human trust](human-role-trust-policy.json) is instantiated separately for
Observer and Diagnostics, each with its designated Braintrust source role.

## Trusted principals and inputs

| Placeholder | Meaning |
| --- | --- |
| `<BRAINTRUST_DEPLOYMENT_PRINCIPAL_ARN>` | Exact Braintrust execution role dedicated to this bootstrap |
| `<BRAINTRUST_HUMAN_PRINCIPAL_ARN>` | Exact designated source role, resolved separately for each human role |
| `<UNIQUE_EXTERNAL_ID>` | Cryptographically random External ID unique to the deployment trust relationship |

Source role ARNs are limited to 256 characters; External IDs to 128.
Do not truncate existing identities or random values. Use the
[required target IAM paths](../policies/README.md#naming-and-scope).
Trust exact role ARNs, not the entire Braintrust account.

## Session requirements

- Deployment assumption requires the exact principal, unique External ID,
  and `byoc-operation-<operation-id>` source identity. The deployment service
  validates the operation and records its attribution.
- Human sessions must inherit a source identity bound to the authenticated
  employee by Braintrust's identity provider or broker. Caller-selected session
  names are not a substitute.
- Source identity provides attribution, not group authorization. Braintrust's
  identity system controls eligibility and MFA. Every role-chain hop must allow
  `sts:SetSourceIdentity`.
- Maximum AWS session duration is one hour. The two-hour Diagnostics window is
  separate; engineers may obtain fresh credentials while it remains active.

Keep the deployment trust's STS statements separate. `sts:AssumeRole` requires
External ID; `sts:SetSourceIdentity` and `sts:TagSession` require the same
principal and source identity, but not External ID.

AWS console Switch Role cannot supply External ID or establish the required
source identity. Human console access needs a tested federated session carrying
that identity; do not weaken trust for console convenience.

## Revocation

Customers can remove Braintrust trust at any time. Deployment cannot restore it.
Trust removal blocks new assumptions, not already-issued credentials or
connections. Also revoke role sessions, remove diagnostic attachments, and
terminate active sessions as described in [Diagnostics](../diagnostics.md#customer-revocation).

See [AWS source identity](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_monitor.html)
and [role session revocation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html).
