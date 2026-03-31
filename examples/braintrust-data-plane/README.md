This is an example of a standard **production-sized** Braintrust data plane deployment. Copy this directory to a new directory in your own repository and modify the files to match your environment.

> [!TIP]
> For a smaller deployment suitable for testing and evaluation, see [`examples/braintrust-data-plane-sandbox/`](../braintrust-data-plane-sandbox/).

## Configure Terraform
* `provider.tf` should be modified to use your AWS account and region.
* `terraform.tf` should be modified to use the remote backend that your company uses. Typically this is an S3 bucket and DynamoDB table.
* `main.tf` should be modified to meet your needs for the Braintrust deployment. The defaults are sensible only for a small development deployment.
* Brainstore requires a license key which you can find in the Braintrust UI under Settings > Data Plane
![Brainstore License Key](../../assets/Brainstore-License-Key.png)
* It isn't recommended that you commit this license key to your git repo. You can safely pass this key into terraform multiple ways:
  * Set `TF_VAR_brainstore_license_key=your-key` in your terraform environment
  * Pass it into terraform as a flag `terraform apply -var 'brainstore_license_key=your-key'`
  * Add it to an uncommitted `terraform.tfvars` or `.auto.tfvars` file.

## Initialize your AWS account
If you're using a brand new AWS account for your Braintrust data plane you will need to run ./scripts/create-service-linked-roles.sh once to ensure IAM service-linked roles are created.

## Pointing your Organization to your data plane

After applying this configuration you will have a Braintrust data plane deployed in your AWS account. You can then run `terraform output` to get the API URL you need to enter into the Braintrust UI for your Organization.
```
❯ terraform output
api_url = "https://dx6ntff6gocr6.cloudfront.net"
```

To configure your Organization to use your new data plane, click your user icon on the top right > Settings > Data Plane.

> [!WARNING]
> If you are testing, it is HIGHLY recommended that [you create a new Braintrust Organization](https://www.braintrust.dev/app/setup) for testing your new data plane. If you change your live Organization's API URL, you might break users who are currently using it.

![Setting the API URL in Braintrust](../../assets/Braintrust-API-URL.png)

Click Edit

![Edit the API URL in Braintrust](../../assets/Braintrust-API-URL-Edit.png)

Paste the API URL into the text field, and click Save. Leave the Proxy and Realtime URL blank.

![Paste the API URL](../../assets/Braintrust-API-URL-set.png)

Verify in the UI that the ping to each endpoint is successful.
![Verify Successful Ping](../../assets/Braintrust-API-URL-verify.png)

## Tearing down

### Step 1: Disable RDS deletion protection

Deletion protection is enabled by default (recommended for production). You must disable it before `terraform destroy` will succeed:

```bash
aws rds modify-db-instance \
  --db-instance-identifier <deployment_name>-main \
  --no-deletion-protection \
  --apply-immediately
```

Alternatively, set `DANGER_disable_database_deletion_protection = true` in `main.tf` and run `terraform apply` before destroying.

### Step 2: Delete quarantine Lambda functions

The quarantine VPC is enabled by default (`enable_quarantine_vpc = true`). The quarantine warmup Lambda creates ~30 functions outside Terraform state. These hold ENIs in the quarantine VPC subnets that block `terraform destroy`. You must delete them before destroying.

Use the included cleanup script (requires [uv](https://docs.astral.sh/uv/)):

```bash
# Dry run — lists quarantine Lambdas without deleting
../../scripts/delete-quarantine-lambdas.py <deployment_name>-quarantine

# Delete them
../../scripts/delete-quarantine-lambdas.py <deployment_name>-quarantine --delete
```

The `<deployment_name>-quarantine` argument is the Name tag of the quarantine VPC (e.g., `braintrust-quarantine`).

### Step 3: Empty S3 buckets

The Braintrust platform writes data to S3 buckets after deployment. S3 buckets must be empty before they can be deleted, so `terraform destroy` will fail if any objects exist.

Use the included cleanup script (requires [uv](https://docs.astral.sh/uv/)):

```bash
# Dry run — lists buckets and object counts
../../scripts/empty-s3-buckets.py <deployment_name>

# Empty them
../../scripts/empty-s3-buckets.py <deployment_name> --delete
```

### Step 4: Wait for ENIs to release, then destroy

After deleting the quarantine Lambda functions, wait ~5 minutes for AWS to release the ENIs, then run:

```bash
terraform destroy
```
