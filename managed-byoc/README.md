# Bring your own cloud (BYOC)

[Braintrust BYOC](https://docs.braintrust.dev/admin/deployment/byoc) lets customers run the Braintrust data plane inside a dedicated customer AWS account while Braintrust manages deployment and ongoing operation with the customer's approval and security controls.

## Deployment sequence

### 1. Agree on the deployment design

For each environment, agree on the AWS account and region, network and endpoint model, sizing and capacity profile, and operational contacts.

### 2. Prepare a dedicated AWS account

Use an AWS account dedicated to Braintrust-managed resources only. Do not use an account that is shared with any other production or non-Braintrust infrastructure.

If you do not already have a dedicated account, work with your infrastructure/platform team to provision one before continuing. You must have full administrative permissions in that account to complete the remaining customer setup steps.

### 3. Set up the Braintrust organization and license

[Create a Braintrust organization](https://docs.braintrust.dev/admin/organizations#create-an-organization), or ask your Braintrust contact to create one. If you create it, send its name to your contact so they can issue the license key.

### 4. Add the license key to AWS Secrets Manager

In the organization created in the previous step, open **Settings > Brainstore** and copy the license key. In the dedicated AWS account and region for this environment, create a Secrets Manager secret named `brainstore-license-key` and store the key as its raw plaintext value, without a JSON key.

### 5. Create the Braintrust management role

Run the following script in the customer AWS account dedicated to Braintrust-managed infrastructure. You can optionally provide an AWS profile with the `--profile` flag.

The script requires the AWS CLI, `jq`, and `uuidgen`.

```bash
# Run using the specified profile. Leave off to use the default profile.
./managed-byoc/create-management-role.sh --profile <aws-profile>
```

The script sets an ExternalId in the role trust policy for cross-account protection. On first create it auto-generates a value in the form `braintrust-<uuid>`. Re-running against an existing role generates a new ExternalId if it doesn't exist, or preserves the existing ExternalId.

Keep the printed **Role ARN** and **External ID** for the deployment handoff to Braintrust.

This role and policy set is the required baseline for managed BYOC. You can review the Trust Policy and Inline Policy in the following files:

- Trust Policy: `managed-byoc/policies/management-role-trust-policy.json` (base policy; ExternalId is always injected by the script at runtime)
- Inline Policy: `managed-byoc/policies/management-role-policy.json`

### Updating the management role policy on an existing role

The inline policy changes from release to release. Release `v7.3.0` adds `scheduler:*`, which the deployment needs to manage EventBridge Scheduler schedules. It also renames the statement IDs (the `Sid` values) in the policy.

Braintrust won't update the policy on your role for you. You run the script. The `--policy-only` flag applies the new policy to an existing role.

```bash
./managed-byoc/create-management-role.sh --profile <aws-profile> --policy-only
```

This only runs `aws iam put-role-policy` on the existing role. It does not call `update-assume-role-policy` or `update-role`, so your trust policy, ExternalId and max session duration stay exactly as they are. This is because a full re-run rewrites the trust policy and session duration, which would overwrite any changes you've made to them. Pass `--role-name` if you didn't use the default role name.

Before it asks you to continue, the script shows a diff between the policy currently on the role and the new one. It exits with an error if the role doesn't exist, or if the role has no inline policy with the expected name. It needs `jq` for the diff.

**Note** - `--policy-only` replaces the whole inline policy document. Any edits you made to the inline policy are removed, so re-apply them afterwards, or keep them in a separate policy attached to the role. The script updates the policy named by the `INLINE_POLICY_NAME` environment variable (default `BraintrustManagementRolePolicy`). Set it if you used a different name when you created the role.

The `Sid` renames only change capitalization, for example `AllowLimitedIam` becomes `AllowLimitedIAM`. They don't change what the policy allows or denies, so you don't need to do anything about them. If you copied `byoc-service-control-policy.json` into your organization, its renamed statement IDs are cosmetic as well, and your deployed SCP keeps working unchanged.

Apply this update before you upgrade a stack to v8. The v8 apply replaces the EventBridge rules with Scheduler schedules, so a deploy role without `scheduler:*` can leave the scheduled Lambdas stopped until the role is fixed. If you use an allow-list SCP, add `scheduler` to it before v8 too, since an SCP that doesn't allow the service blocks it no matter what the role policy says.

You can check the result with read-only credentials before upgrading. The principal you run this with needs `iam:SimulatePrincipalPolicy`.

```bash
aws iam simulate-principal-policy \
  --profile <aws-profile> \
  --policy-source-arn arn:aws:iam::<account-id>:role/BraintrustManagementRole \
  --action-names scheduler:CreateScheduleGroup scheduler:CreateSchedule iam:PassRole iam:TagRole iam:TagPolicy iam:TagInstanceProfile \
  --query 'EvaluationResults[].[EvalActionName,EvalDecision]' \
  --output table
```

Each action should show `allowed`. Simulation doesn't evaluate every service control policy or resource policy, so treat it as a preflight check and not proof.

### Tag permissions for IAM ownership

Release `v7.3.0` also tags every IAM role, managed policy and instance profile that the module creates with `BraintrustIAMOwner = "braintrust"`. This is an in-place tag update on existing stacks, and it needs a few things on your side.

1. The role that runs Terraform needs `iam:TagRole`, `iam:TagPolicy` and `iam:TagInstanceProfile`, plus `iam:ListRoleTags`, `iam:ListPolicyTags` and `iam:ListInstanceProfileTags` so Terraform can read the tags back. The management role policy already grants the three tagging actions, and its `iam:List*` grant covers the `List*Tags` actions. Check them if you narrowed that policy.
1. Check any SCP or permissions boundary that has a condition on tag keys, such as `aws:RequestTag` or `aws:TagKeys`. This is the most likely thing to block the new tag.
1. An organization tag policy only matters if it defines `BraintrustIAMOwner` or a differently cased variant of it. Tag policies don't block keys they don't mention.
1. IAM allows 50 tags per resource. A role that is already close to that limit can't take another tag.

The module reserves this key, so setting it in `custom_tags` fails at plan time, in any letter case. Don't set it through the AWS provider's `default_tags` either. The module can't validate those, and the module's own value has to be the one that applies.

### Optional: Add an AWS Organizations service control policy guardrail

You can create a service control policy (SCP) to restrict the management
role's permissions further. Here is an [example](https://github.com/braintrustdata/terraform-aws-braintrust-data-plane/blob/main/managed-byoc/policies/byoc-service-control-policy.json)
that denies billing, organization/landing-zone, Identity Center,
Marketplace/WorkSpaces, and IAM user/group management actions while leaving the
data-plane deployment surface available. Please share any proposed SCP with
Braintrust for review before applying it so that we can ensure it does not
block required deployment and management operations.

Additionally you should review the policy with your AWS organization administrator before attaching it:

- SCPs apply to all principals in attached accounts, including administrative
  roles you may have created for yourself.
- Explicit deny statements in the SCP override identity-based allows.
- Prefer attaching it to a dedicated organizational unit or account used for
  Braintrust-managed infrastructure.

### 6. Check service quotas

New AWS accounts often need quota increases before deployment can succeed.

This directory includes:

- `managed-byoc/quota-config.json`: default required quotas
- `managed-byoc/manage-quotas.sh`: script to inspect/request quota increases

View current quotas against the required values:

```bash
./managed-byoc/manage-quotas.sh --profile <aws-profile> list
```

This prints each quota with its current value, desired value, and action (`ok` / `needs-raise`).

Request increases for quotas below target values:

```bash
./managed-byoc/manage-quotas.sh --profile <aws-profile> request
```

The script submits requests to AWS and prints request IDs. Some requests may open AWS Support cases or need clarification. Monitor their status in the AWS console and respond to any AWS follow-up.

### 7. Send Braintrust the deployment handoff

For each environment, send your Braintrust contact the organization name, AWS account ID, region, management role ARN, External ID, confirmation that the `brainstore-license-key` secret is present, network and endpoint decisions, sizing and capacity profile, and operational contacts. Do not include the license key itself.

### 8. Braintrust deploys the data plane

Braintrust applies the deployment and provides the data plane API URL. If your team created the organization, open **Settings > Data Plane** and enter that URL in the **API URL** field. Braintrust then validates data plane health with you.
