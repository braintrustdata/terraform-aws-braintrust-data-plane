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

3. **Deploy the infrastructure** (initial deployment):
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Create your EKS cluster** (outside of this Terraform module):
   - Deploy your EKS cluster in your AWS account
   - Note the EKS cluster ARN, namespace, and security group ID

5. **Configure post-EKS settings** (after EKS cluster exists):

   After your EKS cluster is created, update `main.tf` with the following configurations and re-apply:

   a. **Enable EKS Pod Identity or IRSA**:

      ```hcl
      existing_eks_cluster_arn = "<your EKS cluster ARN>"
      eks_namespace = "<your EKS namespace>"
      ```

   b. **Configure database and Redis security groups**:

      ```hcl
      database_authorized_security_groups = {
        "<your EKS cluster security group name>" = "<your EKS cluster security group ID>"
      }
      redis_authorized_security_groups = {
        "<your EKS cluster security group name>" = "<your EKS cluster security group ID>"
      }
      ```

   c. **Re-apply Terraform**:

      ```bash
      terraform plan
      terraform apply
      ```

6. **Deploy Braintrust services to EKS**:
   - Set up EKS Pod Identity associations for the Braintrust IAM roles
   - Deploy your Braintrust services to the EKS cluster
   - Ensure services can access the Quarantine VPC

### Deploying Loop Runtime with Helm

Set `enable_loop_runtime = true` after EKS identity configuration. In external
EKS mode Terraform creates the AWS MicroVM image, network connectors, and a
dedicated IAM role; it does not create an ECS service or ALB.

Use the Terraform outputs to configure the Helm chart:

```yaml
cloud: aws

objectStorage:
  aws:
    brainstoreBucket: "<terraform output brainstore_s3_bucket_name>"
    codeBundleBucket: "<terraform output code_bundle_s3_bucket_name>"

loopRuntime:
  enabled: true
  image:
    tag: "<terraform output loop_runtime_version>"
  # Use the role ARN here with IRSA. With Pod Identity, associate this role
  # with the service account instead and leave awsRoleArn empty.
  serviceAccount:
    name: braintrust-loop-runtime # Must match loop_runtime_eks_service_account_name.
    awsRoleArn: "<terraform output loop_runtime_eks_role_arn>"
  sandbox:
    imageIdentifier: "<terraform output loop_runtime_microvm_image_arn>"
    region: "<AWS region>"
    ingressNetworkConnectorArns: "<AWS_LAMBDA_MICROVM_INGRESS_NETWORK_CONNECTOR_ARNS>"
    egressNetworkConnectorArns: "<AWS_LAMBDA_MICROVM_EGRESS_NETWORK_CONNECTOR_ARNS>"
```

The connector values are included in
`terraform output -json loop_runtime_sandbox_env_vars`. The chart reads the
existing `braintrust-secrets` keys (`PG_URL`, `REDIS_URL`,
`FUNCTION_SECRET_KEY`, and `BRAINSTORE_LICENSE_KEY`) and automatically wires
the API's `LOOP_RUNTIME_URL`. Enable `virtualService` if the runtime should be
reachable through the chart-managed Istio ingress.

## Outputs

After deployment, you can get important values using:

```bash
terraform output
```

Key outputs:

**Quarantine VPC Resources:**

- `quarantine_vpc_id` - The Quarantine VPC ID for configuring your EKS services
- `quarantine_invoke_role_arn` - IAM role ARN used by the API handler to invoke quarantined functions
- `quarantine_function_role_arn` - IAM role ARN used by quarantined Lambda functions
- `quarantine_private_subnet_1_id` - First private subnet ID in the quarantine VPC
- `quarantine_private_subnet_2_id` - Second private subnet ID in the quarantine VPC
- `quarantine_private_subnet_3_id` - Third private subnet ID in the quarantine VPC
- `quarantine_vpc_default_security_group_id` - Default security group ID for the quarantine VPC

**Other Resources:**

- `main_vpc_id` - The main VPC ID
- `brainstore_s3_bucket_name` - Name of the Brainstore S3 bucket
- `code_bundle_s3_bucket_name` - Name of the code bundle S3 bucket
- `loop_runtime_eks_role_arn` - IAM role for the Helm-managed Loop Runtime service account
- `loop_runtime_microvm_image_arn` - AWS MicroVM image used by Loop Runtime
- `loop_runtime_version` - Loop Runtime container image and sandbox artifact version
- `loop_runtime_sandbox_env_vars` - Non-secret sandbox settings for Helm

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
