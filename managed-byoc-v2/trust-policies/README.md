# Trust policy reference

[Back to overview](../README.md#start-here)

[Deployment trust](deployment-role-trust-policy.json) is for automation.
[Human trust](human-role-trust-policy.json) is the standing Observer trust.
Diagnostics uses the closed and temporary trust documents below, not the
standing human trust.

## Trusted principals and inputs

| Placeholder | Meaning |
| --- | --- |
| `<BRAINTRUST_DEPLOYMENT_PRINCIPAL_ARN>` | Exact Braintrust execution role dedicated to this bootstrap |
| `<BRAINTRUST_HUMAN_PRINCIPAL_ARN>` | Exact designated Braintrust Observer source role |
| `<BRAINTRUST_DIAGNOSTICS_PRINCIPAL_ARN>` | Exact Braintrust Diagnostics source role |
| `<ENGINEER_SOURCE_IDENTITY>` | Exact authenticated participant identity; repeat array entries for additional engineers |
| `<DIAGNOSTICS_ACCESS_STARTS_AT>`, `<DIAGNOSTICS_ACCESS_EXPIRES_AT>` | UTC timestamps for one recorded access window |
| `<UNIQUE_EXTERNAL_ID>` | Cryptographically random External ID unique to the deployment trust relationship |

Source role ARNs are limited to 256 characters; External IDs to 128.
Do not truncate existing identities or random values. Use the
[required target IAM paths](../policies/README.md#naming-and-scope).
Trust exact role ARNs, not the entire Braintrust account.

## Diagnostics trust states

| State | Complete trust document | Result |
| --- | --- | --- |
| Inactive | [diagnostics-role-trust-policy.json](diagnostics-role-trust-policy.json) | Denies assumption; fixed permissions remain attached |
| Active | [diagnostics-active-trust-policy.json](diagnostics-active-trust-policy.json) | Exact source role and named source identities may assume only within the recorded window |

Activation replaces the closed document; appending an Allow to its Deny would
not open access. Early closure restores closed trust. The active document's
date condition expires independently of later restoration.

List source identities exactly, without wildcards or `IfExists` conditions.
Values must be 2–64 characters supported by AWS SourceIdentity, not start with
`aws:`, and be bound to authenticated employees before entering the Braintrust
source role. A caller-supplied name or email is not proof of identity. The
active document requires inherited `aws:SourceIdentity`, not a newly supplied
value alone. Keep the final participant list within the role's configured trust
policy limit (2,048 characters by default).

The customer can inspect the permitted identities and deadline and correlate
them with CloudTrail. Only the exact customer Diagnostics role is editable by
Deployment; AWS does not restrict the replacement JSON's contents. Independent
revocation must also prevent that trust update or remove Deployment access.

## Session requirements

- Deployment assumption requires the exact principal, unique External ID,
  and `byoc-operation-<operation-id>` source identity. The deployment service
  validates the operation and records its attribution.
- Human sessions must inherit a source identity bound to the authenticated
  employee by Braintrust's identity provider or broker. Caller-selected session
  names are not a substitute.
- Source identity identifies the person; Diagnostics trust uses it to restrict
  participants. Braintrust's identity system controls group eligibility and MFA.
  Every role-chain hop must allow `sts:SetSourceIdentity`.
- Maximum AWS session duration is one hour. The two-hour Diagnostics window is
  separate; engineers may obtain fresh credentials while it remains active.

Keep the deployment trust's STS statements separate. `sts:AssumeRole` requires
External ID; `sts:SetSourceIdentity` and `sts:TagSession` require the same
principal and source identity, but not External ID.

AWS console Switch Role cannot supply External ID or establish the required
source identity. Human console access needs a tested federated session carrying
that identity; do not weaken trust for console convenience.

## Revocation

Customers can remove Deployment or Observer trust; Deployment cannot restore
either. Diagnostics trust is intentionally editable by Deployment, so a durable
customer cutoff must also block those updates or revoke Deployment access.
Trust removal or expiry blocks new assumptions, not already-issued credentials
or connections. See [Diagnostics revocation](../diagnostics.md#customer-revocation)
for immediate cutoff using independent customer access.

See [AWS source identity](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_monitor.html)
and [role session revocation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html).
