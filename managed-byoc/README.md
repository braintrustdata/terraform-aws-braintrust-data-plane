# Managed BYOC

Managed BYOC (Bring Your Own Cloud) is an optional Braintrust offering where a customer provides an AWS account and Braintrust deploys and operates the Braintrust Data Plane in that account.

## Deployment sequence

### 1. Agree on the deployment design

For each environment, agree on the AWS account and region, network and endpoint model, sizing and capacity profile, and operational contacts.

### 2. Prepare a dedicated AWS account

Use an AWS account dedicated to Braintrust-managed resources only. Do not use an account that is shared with any other production or non-Braintrust infrastructure.

If you do not already have a dedicated account, work with your infrastructure/platform team to provision one before continuing. You must have full administrative permissions in that account to complete the remaining customer setup steps.

### 3. Create the Braintrust organization and license

Either Braintrust or the customer can [create the Braintrust organization](https://www.braintrust.dev/docs/admin/organizations#create-an-organization). If the customer creates it, share its name with Braintrust so we can create the corresponding license key.

### 4. Add the license key to AWS Secrets Manager

In the matching Braintrust organization, open **Settings > Data plane > Brainstore configuration** and copy the license key. In the dedicated AWS account and region for this environment, create a Secrets Manager secret named `brainstore-license-key` and store the key as its raw plaintext value, without a JSON key.

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

For each environment, provide Braintrust with the organization name, AWS account ID, region, management role ARN, External ID, confirmation that the `brainstore-license-key` secret is present, network and endpoint decisions, sizing and capacity profile, and operational contacts. Do not include the license key itself.

### 8. Braintrust deploys and validates the data plane

Braintrust prepares and applies the deployment, then validates data plane health with the customer.
