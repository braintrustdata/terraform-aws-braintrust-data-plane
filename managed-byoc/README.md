# Managed BYOC

Managed BYOC (Bring Your Own Cloud) is an optional Braintrust offering where a customer provides an AWS account and Braintrust deploys and operates the Braintrust Data Plane in that account.

## 1) Prepare a dedicated AWS account

Use an AWS account dedicated to Braintrust-managed resources only. Do not use an account that is shared with any other production or non-Braintrust infrastructure.

If you do not already have a dedicated account, work with your infrastructure/platform team to provision one before continuing.

You must have full administrative permissions in that dedicated account to complete the remaining steps in this guide.

## 2) Create the Braintrust management role

Run the following script to create the Braintrust management role. This should be run in the customer AWS account dedicated to Braintrust-managed infrastructure. You can optionally provide an AWS profile to use with the `--profile` flag.

```bash
# Run using the default AWS profile
./managed-byoc/create-management-role.sh --profile <aws-profile>
```

This role and policy set is the required baseline for managed BYOC. You can review the Trust Policy and Inline Policy in the following files:

- Trust Policy: `managed-byoc/policies/management-role-trust-policy.json`
- Inline Policy: `managed-byoc/policies/management-role-policy.json`

## 3) Optional: Organization Service Control Policy (SCP) guardrail

Customers can further restrict access by applying the sample Service Control Policy in:

- `managed-byoc/policies/byoc-service-control-policy.json`

Apply it at the AWS Organizations OU or account level that contains the managed BYOC account. This SCP is optional but recommended when you want additional organizational guardrails.

Notes:

- SCPs apply to all principals in attached accounts. Including any Administrative role you may have created for yourself.
- Explicit deny statements in the SCP override identity-based allows.
- Prefer attaching to a dedicated OU/account used for Braintrust-managed infrastructure.

## 4) Service quota requirements for accounts

New AWS accounts often need quota increases before deployment can succeed.

This directory includes:

- `managed-byoc/quota-config.json`: default required quotas
- `managed-byoc/manage-quotas.sh`: script to inspect/request quota increases

### View current quotas vs required values

```bash
./managed-byoc/manage-quotas.sh --profile <aws-profile> list
```

This prints each quota with current value, desired value, and action (`ok` / `needs-raise`).

### Apply quota increase requests

```bash
./managed-byoc/manage-quotas.sh --profile <aws-profile> request
```

For quotas below target values, the script submits increase requests to AWS and prints request IDs.

### Follow up on support tickets and request outcomes

Some quota requests may open AWS Support cases or require clarification. Customers should monitor quota request status and any support communications in the AWS console and respond as needed. AWS may approve, ask follow-up questions, or deny requests.
