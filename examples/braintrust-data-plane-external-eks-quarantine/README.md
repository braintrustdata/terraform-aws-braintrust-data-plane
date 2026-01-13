# Braintrust Data Plane - External EKS with Quarantine VPC

This is an example configuration for deploying a Braintrust data plane with the following characteristics:

- **External EKS Deployment Mode**: Uses `use_deployment_mode_external_eks = true` to deploy services on an existing EKS cluster managed outside of Terraform
- **EKS Pod Identity**: Enables `enable_eks_pod_identity = true` for the Braintrust IAM roles
- **Quarantine VPC**: Deploys the Quarantine VPC (`enable_quarantine_vpc = true`) for running user-defined functions in an isolated environment

## Quarantine VPC IAM Permissions

The Quarantine VPC IAM permissions are automatically deployed when `enable_quarantine_vpc = true`, even when using `use_deployment_mode_external_eks = true`. These IAM resources are created in the `services-common` module:

- `QuarantineInvokeRole` - Role used by the API handler to invoke quarantined functions
- `QuarantineFunctionRole` - Role used by the quarantined Lambda functions  
- `APIHandlerQuarantinePolicy` - Policy attached to the API handler role for quarantine operations

These resources are available for use by your EKS-deployed services via EKS Pod Identity.

## Configuration

### Required Settings

1. **EKS Configuration**:
   - Set `use_deployment_mode_external_eks = true`
   - Set `enable_eks_pod_identity = true`
   - Optionally set `existing_eks_cluster_arn` to restrict trust policies
   - Optionally set `eks_namespace` to restrict trust policies

2. **Quarantine VPC**:
   - Set `enable_quarantine_vpc = true` (this is the default)
   - Optionally customize `quarantine_vpc_cidr` if needed

### Setup Steps

1. **Configure Terraform**:
   - Modify `provider.tf` to use your AWS account and region
   - Modify `terraform.tf` to use your remote backend (S3, etc.)
   - Update `main.tf` with your organization name and any custom settings

2. **Initialize your AWS account**:
   - If using a brand new AWS account, run `./scripts/create-service-linked-roles.sh` once

3. **Deploy the infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure your EKS cluster**:
   - Set up EKS Pod Identity associations for the Braintrust IAM roles
   - Deploy your Braintrust services to the EKS cluster
   - Ensure services can access the Quarantine VPC

## Outputs

After deployment, you can get important values using:

```bash
terraform output
```

Key outputs:
- `quarantine_vpc_id` - The Quarantine VPC ID for configuring your EKS services
- `api_handler_role_arn` - The API handler IAM role ARN for EKS Pod Identity
- `main_vpc_id` - The main VPC ID

## Network Configuration

⚠️ **WARNING**: Choose your VPC CIDR blocks carefully. Changing them after deployment requires a complete rebuild.

- Main VPC CIDR: Default is `10.175.0.0/21`
- Quarantine VPC CIDR: Default is `10.175.8.0/21`

Ensure these don't conflict with:
- Other VPCs you plan to peer with Braintrust
- Your EKS cluster's VPC
- Any other network resources in your AWS account

## Additional Resources

- See the main [README.md](../../README.md) for general information
- See [examples/braintrust-data-plane/README.md](../braintrust-data-plane/README.md) for standard deployment examples
