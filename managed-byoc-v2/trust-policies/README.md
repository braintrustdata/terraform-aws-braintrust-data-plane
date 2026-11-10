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
| `<ENGINEER_SOURCE_IDENTITY>` | Exact IAM Identity Center UserId from the authenticated login context; repeat array entries for 1–10 approved engineers |
| `<DIAGNOSTICS_ACCESS_EXPIRES_AT>` | Absolute UTC deadline for the activation |
| `<UNIQUE_EXTERNAL_ID>` | Cryptographically random External ID unique to the deployment trust relationship |

Source role ARNs are limited to 256 characters; External IDs to 128.
Do not truncate existing identities or random values. Use the
[required target IAM paths](../policies/README.md#naming-and-scope).
Trust exact role ARNs, not the entire Braintrust account.

## Diagnostics trust states

| State | Complete trust document | Result |
| --- | --- | --- |
| Inactive | [diagnostics-role-trust-policy.json](diagnostics-role-trust-policy.json) | Denies assumption; fixed permissions remain attached |
| Customer-disabled | [diagnostics-disabled-trust-policy.json](diagnostics-disabled-trust-policy.json) | Denies assumption; bootstrap also denies Deployment trust updates |
| Active | [diagnostics-active-trust-policy.json](diagnostics-active-trust-policy.json) | Exact source role and approved verified UserIds may assume before the deadline |

Activation replaces the closed document; appending an Allow to its Deny would
not open access. Early closure restores closed trust and takes time to propagate.
The active document's fixed date condition expires independently of later
restoration. Reading the changed policy does not prove STS has observed it.

List source identities exactly, without wildcards or `IfExists` conditions.
Values must be 2–64 characters supported by AWS SourceIdentity, not start with
`aws:`, and identify distinct authenticated employees. A caller-supplied name or
email is not proof of identity. Active trust requires AWS's signed
`identitystore:UserId`, membership in the approved list, and requested
`sts:SourceIdentity` equal to that verified UserId. The login path need not
prepopulate SourceIdentity. It must provide the signed identity context.
Keep the final participant list within the role's configured trust policy limit
(2,048 characters by default); the validator exercises ten maximum-length IDs.

The customer role's session name must equal the same verified UserId. This
preserves the fixed own-session permissions, which use `aws:userid` (role ID
plus session name). A separate Deny enforces that name only for `sts:AssumeRole`;
`sts:SetSourceIdentity` authorization lacks the session-name context. Combining
that restriction with the latter action would block valid assumptions.

The customer can inspect the permitted identities and deadline and correlate
them with CloudTrail. Only the exact customer Diagnostics role is editable by
Deployment; AWS does not restrict the replacement JSON's contents. Independent
revocation must also prevent that trust update or remove Deployment access.
The bootstrap's customer-disable policy provides the direct Deployment deny;
review its [enforcement limits](../diagnostics.md#customer-owned-disable-control).

## Session requirements

- Deployment assumption requires the exact principal, unique External ID,
  and `byoc-operation-<operation-id>` source identity. The deployment service
  validates the operation and records its attribution.
- Observer retains its standing human trust and inherited source-identity
  requirement. Diagnostics instead uses the verified UserId binding above.
- Braintrust's identity system controls eligibility and MFA for the Diagnostics
  source role. That eligibility alone does not grant customer access: the
  engineer must also appear in the current activation's participant list.
- Source permissions and customer trust must both permit `sts:AssumeRole` and
  `sts:SetSourceIdentity` for the approved path. Diagnostics does not need
  `sts:TagSession` in customer trust.
- Maximum AWS session duration is one hour. The two-hour Diagnostics window is
  separate; engineers may obtain fresh credentials while it remains active.

Keep the deployment trust's STS statements separate. `sts:AssumeRole` requires
External ID; `sts:SetSourceIdentity` and `sts:TagSession` require the same
principal and source identity, but not External ID.

AWS console Switch Role cannot supply External ID or establish the required
source identity. Human console access needs a tested federated session carrying
that identity; do not weaken trust for console convenience.

## Revocation

Customers can remove Deployment or Observer trust; Deployment cannot directly
restore either. Set the customer-owned `DiagnosticsActivationEnabled` parameter
to `false` to install the protected Deployment deny and reset Diagnostics trust.
Re-enabling returns to inactive trust; it does not restore a prior grant.
Trust changes take time to propagate; the unchanged deadline blocks new
assumptions without a write. Neither invalidates already-issued credentials or
connections. See [Diagnostics revocation](../diagnostics.md#customer-revocation)
for emergency customer actions and their limits.

See [AWS source identity](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_control-access_monitor.html)
and [role session revocation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_revoke-sessions.html).
