# Trust policy review guide

- Replace each principal placeholder with one exact Braintrust IAM role ARN;
  do not trust the entire Braintrust AWS account.
- Use a separate human trust policy instance for the support and observer
  roles, each with its own exact source role used by SSO.
- Generate a unique, cryptographically random External ID for each customer
  deployment trust relationship. It is required only for the machine role.
- Set the target roles' maximum session duration to one hour. AWS role chaining
  already caps chained sessions at one hour.
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

Validate the complete SSO or broker flow before enabling either human role.
Ordinary console Switch Role cannot establish a required source identity;
console access needs a tested federated or brokered session that carries it. Do
not remove the attribution requirement merely to make Switch Role work.

Changing trust stops new sessions, not credentials already issued. The customer
runbook must also cover [revoking active role sessions](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html).
See [AWS source identity guidance](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_monitor.html).
