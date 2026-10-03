# Trust policy review guide

[Back to overview](../README.md#start-here)

Review [deployment-role-trust-policy.json](deployment-role-trust-policy.json) for
the machine role and [human-role-trust-policy.json](human-role-trust-policy.json)
for Support, Observer, and Diagnostics. The human policy is instantiated separately
for each role with its designated Braintrust source principal.

Use the [bootstrap IAM naming rules](../policies/README.md#naming-and-scope) for
all target roles. These additional placeholders configure the trusted sources:

| Placeholder | Meaning |
| --- | --- |
| `<BRAINTRUST_DEPLOYMENT_PRINCIPAL_ARN>` | Exact Braintrust execution role ARN dedicated to this bootstrap |
| `<BRAINTRUST_HUMAN_PRINCIPAL_ARN>` | Exact designated Braintrust source role ARN, resolved separately for each human role |
| `<UNIQUE_EXTERNAL_ID>` | Random External ID unique to the deployment trust relationship |

For this package, keep source role ARNs within 256 characters and External IDs
within 128 characters. Do not shorten existing identities or truncate random
values to meet a limit; generate compatible bootstrap inputs and validate the
complete rendered policies.

- Replace each principal placeholder with one exact Braintrust IAM role ARN;
  do not trust the entire Braintrust AWS account.
- Use a separate human trust policy instance for Support, Observer, and
  Diagnostics, each with its designated exact source role used by SSO.
  Diagnostics trust does not grant diagnostic permissions on its own.
- Generate a unique, cryptographically random External ID for each customer
  deployment trust relationship. It is required only for the machine role.
- Set the target roles' maximum session duration to one hour. AWS role chaining
  already caps chained sessions at one hour. The Diagnostics activation window
  lasts two hours and is separate; an engineer may obtain fresh credentials while
  it remains active.
- Human sessions must already carry a source identity from the trusted
  Braintrust identity provider or access broker. The human trust policy rejects
  an upstream session without it. Upstream controls must bind that value to the
  authenticated employee, not let employees select another person's identity.
- Machine sessions require `byoc-operation-<operation-id>` as their source
  identity. Trust enforces the prefix; the deployment service validates the
  operation ID and records it with the deployment operation and module version.
  Session names or tags can add change references; they do not grant permissions.
- The AWS console cannot supply an External ID during role switching, so the
  human roles trust exact source roles instead.

Source identity is audit attribution, not an SSO group selector. Membership,
MFA, and eligibility to assume the source role are enforced by Braintrust's
identity system. AWS preserves source identity across role chains. Each hop
must allow `sts:SetSourceIdentity` in its trust and applicable caller policies.

Validate the complete SSO or broker flow before enabling any human role.
Ordinary console Switch Role cannot establish a required source identity;
console access needs a tested federated or brokered session that carries it. Do
not remove the attribution requirement merely to make Switch Role work.

Changing trust stops new sessions, not credentials already issued. The customer
runbook must also cover [revoking active role sessions](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html)
and terminating active diagnostic connections.
See [AWS source identity guidance](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_monitor.html).

For Diagnostics, customers may remove Braintrust trust at any time. Deployment
cannot restore it. Also remove diagnostic permissions and terminate active SSM/ECS
sessions when closing access; neither trust changes nor an expired activation
record alone ends every connection. See [Diagnostics](../diagnostics.md).
