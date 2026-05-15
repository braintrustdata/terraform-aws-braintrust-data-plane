# EKS Cluster Module

This module creates an Amazon EKS cluster with managed node groups for running Braintrust workloads on Kubernetes.

## Features

- **EKS Cluster**: Creates a fully configured EKS cluster with encryption, logging, and OIDC identity provider
- **Three Node Groups**:
  - **System**: For Kubernetes system components (CoreDNS, kube-proxy, etc.)
  - **Services**: For Braintrust API services
  - **Brainstore**: For Brainstore analytics workloads
- **EKS Addons**: Automatically installs and manages:
  - VPC CNI for networking
  - CoreDNS for service discovery
  - kube-proxy for service routing
  - EBS CSI driver for persistent volumes
  - Pod Identity agent for workload identity
- **Security**: KMS encryption for secrets, IAM roles with least privilege, security groups
- **Pod Identity Associations**: Associates the Braintrust API, Brainstore, and AWS Load Balancer Controller service accounts with IAM roles
- **Access Entries**: Optionally creates EKS access entries and access policy associations for human or CI operators
- **Auto-scaling**: All node groups support auto-scaling

## Architecture

Similar to the Azure AKS and GCP GKE modules, this creates:
- A managed EKS control plane
- Multiple node groups for different workload types
- Proper IAM roles and policies for cluster and nodes
- Integration with AWS services (KMS, CloudWatch)

## Usage

```hcl
module "eks_cluster" {
  source = "./modules/eks-cluster"

  deployment_name     = var.deployment_name
  kubernetes_version = "1.31"

  # Networking
  subnet_ids = [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id
  ]

  enable_private_access = true
  enable_public_access  = true
  public_access_cidrs   = ["203.0.113.10/32"]

  eks_access_entries = {
    support_viewer = {
      principal_arn = "arn:aws:iam::123456789012:role/BraintrustSupportViewer"
      policy_associations = {
        braintrust_logs = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["braintrust"]
          }
        }
      }
    }
  }

  # Encryption
  kms_key_arn = local.kms_key_arn

  # Workload identity
  braintrust_namespace           = "braintrust"
  braintrust_api_service_account = "braintrust-api"
  brainstore_service_account     = "brainstore"
  braintrust_api_role_arn        = module.services_common.api_handler_role_arn
  brainstore_role_arn            = module.services_common.brainstore_iam_role_arn

  # Node Groups
  system_node_group_instance_type = "t3.medium"
  system_node_group_desired_size  = 2
  system_node_group_min_size      = 2
  system_node_group_max_size      = 4

  services_node_group_instance_type = "r6i.2xlarge"
  services_node_group_desired_size  = 2
  services_node_group_min_size      = 2
  services_node_group_max_size      = 10

  brainstore_node_group_instance_type = "c8gd.8xlarge"
  brainstore_node_group_desired_size  = 5
  brainstore_node_group_min_size      = 3
  brainstore_node_group_max_size      = 10

  custom_tags = var.custom_tags
}
```

## Node Group Sizing

### System Node Group
- **Default**: t3.medium
- **Purpose**: Runs Kubernetes system components
- **Sizing**: Small instances are sufficient, typically 2-4 nodes

### Services Node Group
- **Default**: r6i.2xlarge (memory-optimized)
- **Purpose**: Runs Braintrust API services
- **Sizing**: Memory-optimized instances recommended, scale based on API load

### Brainstore Node Group
- **Default**: c8gd.8xlarge (Graviton4, ARM64, local NVMe required)
- **AMI**: AL2023_ARM_64_STANDARD (set via `brainstore_node_group_ami_type`)
- **Purpose**: Runs Brainstore analytics workloads
- **Sizing**: Local NVMe is required for caching performance. The default c8gd.8xlarge (32 vCPU / 64 GiB) fits the brainstore writer pod and leaves capacity for readers on separate nodes.

## Outputs

- `cluster_id`: EKS cluster name
- `cluster_arn`: EKS cluster ARN
- `cluster_endpoint`: API server endpoint
- `cluster_oidc_issuer_url`: OIDC issuer URL for IRSA
- `cluster_certificate_authority_data`: CA certificate for kubectl
- `braintrust_api_pod_identity_association_id`: Pod Identity association for the API service account
- `brainstore_pod_identity_association_id`: Pod Identity association for the Brainstore service account
- Node group IDs and statuses

## Requirements

- Terraform >= 1.3
- AWS Provider >= 5.0
- At least 2 subnets in different availability zones
- KMS key for encryption
