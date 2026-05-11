# `eks-cluster` submodule

Provisions the EKS Auto Mode cluster plus the AWS-side networking and CloudFront ingress that feeds it. Instantiated by the root module when `create_eks_cluster = true`; not intended for direct consumption.

## What this submodule owns

- EKS Auto Mode cluster (`${deployment_name}-eks`)
- IAM role + policy attachments for the cluster control plane (five AWS-managed policies required by Auto Mode)
- IAM role + policy attachments for Auto Mode nodes
- `aws_ec2_tag` entries on private subnets marking them as `kubernetes.io/role/internal-elb: "1"` so the LB Controller auto-discovers them
- Pre-created internal NLB (`${deployment_name}-api-nlb`) adopted by the LB Controller at Helm release time — pre-creation is required because CloudFront VPC Origin needs the NLB ARN at plan time
- NLB security group allowing CloudFront-origin prefix-list ingress on port 8000
- Cluster SG ingress rule for TCP 8000 from the NLB SG (container-port ingress, required for `ip` target-type NLB health checks; AWS-managed controllers don't add this when the NLB SG is user-provided)
- CloudFront VPC Origin wrapping the NLB
- CloudFront distribution with deployment-local routing for `/function/*`, `/v1/proxy*`, and `/v1/eval*` paths

## What this submodule does not own

- Any Kubernetes resources (that's `eks-deploy`)
- Any IAM roles consumed *inside* the cluster via Pod Identity (those live in `services_common` and are passed in via ARN, since they're shared with the non-EKS path)
- VPC / subnets / route tables (owned by the `vpc` submodule)
- RDS / ElastiCache / S3 / KMS (owned by their respective submodules)

## Key outputs

| Output | Purpose |
|---|---|
| `cluster_name`, `cluster_arn` | Consumed by `services_common` for Pod Identity trust policy scoping |
| `cluster_endpoint`, `cluster_certificate_authority_data` | Consumed by the root module's outputs, which feed the customer's kubernetes/helm providers |
| `cluster_security_group_id` | Used as the destination for RDS/Redis ingress SG rules |
| `node_iam_role_name` | Passed into the NodeClass `spec.role` in `eks-deploy` |
| `nlb_arn`, `nlb_name`, `nlb_security_group_id` | Consumed by `eks-deploy` for the chart's NLB-adoption annotations |
| `cloudfront_distribution_domain_name`, `cloudfront_distribution_arn` | Exposed as root-level outputs for customer DNS/routing |

## Customization surface

Direct consumers would configure this submodule with:

- `deployment_name` — the one identifier threaded through every resource name and tag
- `vpc_id`, `private_subnet_ids` — the VPC this cluster lives in (provided by the `vpc` submodule or an existing VPC)
- `eks_kubernetes_version` — K8s version (default `1.31`)
- `cloudfront_price_class`, `custom_domain`, `custom_certificate_arn`, `waf_acl_id` — optional CloudFront tuning
- `permissions_boundary_arn`, `custom_tags` — standard cross-cutting

See `variables.tf` for the full list with descriptions.
