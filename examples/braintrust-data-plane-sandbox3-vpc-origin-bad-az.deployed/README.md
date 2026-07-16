# erikdw-sandbox3 — VPC origin bad-AZ upgrade test

Tests upgrading an existing us-east-1 deployment where **private subnet 2 is in `use1-az3`** (unsupported for CloudFront VPC origins).

## Setup

```bash
export AWS_PROFILE=sandbox-usw2
export AWS_REGION=us-east-1
cd examples/braintrust-data-plane-sandbox3-vpc-origin-bad-az.deployed
```

Set `brainstore_license_key` via `terraform.tfvars` (gitignored) or `TF_VAR_brainstore_license_key`.

## Phase 1 — baseline (main module, bad AZ on gateway ALB)

In `main.tf`:

```hcl
module_source                = "github.com/braintrustdata/terraform-aws-braintrust-data-plane?ref=main"
use_private_ai_gateway_origin = false
```

```bash
terraform init -upgrade
terraform apply
```

Verify gateway ALB uses **3 subnets** (includes use1-az3):

```bash
terraform output gateway_alb_subnet_ids
aws elbv2 describe-load-balancers --names erikdw-sandbox3-gateway --query 'LoadBalancers[0].AvailabilityZones'
```

## Phase 2 — upgrade (module with fixes)

In `main.tf`:

```hcl
module_source                = "../../"
use_private_ai_gateway_origin = true
```

```bash
terraform init -upgrade
terraform plan   # expect gateway ALB subnet change (3 → 2), CloudFront VPC origin adds
terraform apply
```

Verify:

```bash
terraform output gateway_alb_subnet_ids   # should be 2 subnets, excluding use1-az3
```

Smoke `/v1/proxy` via `terraform output api_url`.

## Teardown

```bash
terraform destroy
```
