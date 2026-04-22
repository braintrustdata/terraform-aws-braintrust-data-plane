# tflint-ignore-file: terraform_module_pinned_source

# Example: Fully Terraform-managed EKS-based Braintrust data plane.
#
# This example is a thin configuration layer — all logic (EKS cluster, OIDC,
# addons, NLB, CloudFront, Kubernetes namespace + secret, Helm releases) lives
# inside the module. The example just sets variables and configures providers.
#
# IMPORTANT — two-step apply required on first deployment:
#
#   Step 1: terraform apply -target=module.braintrust.module.eks[0]
#   Step 2: terraform apply
#
# Step 1 creates the EKS cluster so the kubernetes/helm providers in
# provider.tf can resolve the cluster endpoint via data.aws_eks_cluster.
# Step 2 deploys the K8s namespace, secret, and Helm releases.

module "braintrust" {
  source = "../../"
  # For production use, pin to a released version:
  # source = "github.com/braintrustdata/terraform-braintrust-data-plane?ref=vX.Y.Z"

  deployment_name        = var.deployment_name
  braintrust_org_name    = var.braintrust_org_name
  brainstore_license_key = var.brainstore_license_key

  # EKS deployment mode — disables Lambda, EC2 Brainstore, and Lambda-based ingress
  use_deployment_mode_external_eks = true
  # Create and manage the EKS cluster with Terraform
  create_eks_cluster = true

  eks_namespace      = var.eks_namespace
  helm_chart_version = var.helm_chart_version

  brainstore_wal_footer_version  = var.brainstore_wal_footer_version
  skip_pg_for_brainstore_objects = var.skip_pg_for_brainstore_objects

  # Disable quarantine VPC (Lambda-based, not relevant for EKS mode)
  enable_quarantine_vpc = false

  ### Postgres
  postgres_instance_type              = "db.r8g.2xlarge"
  postgres_storage_size               = 1000
  postgres_max_storage_size           = 10000
  postgres_storage_type               = "gp3"
  postgres_storage_iops               = 15000
  postgres_storage_throughput         = 500
  postgres_version                    = "15"
  postgres_auto_minor_version_upgrade = true

  ### Redis
  redis_instance_type = "cache.t4g.medium"
  redis_version       = "7.0"

  ### Sandbox helm overrides (example — uncomment and adjust for smaller
  ### deployments than the chart's production defaults assume).
  # eks_node_instance_type = "c8gd.2xlarge"
  # eks_node_desired_size  = 2
  # eks_api_helm = {
  #   replicas = 1
  #   resources = {
  #     requests = { cpu = "500m", memory = "1Gi" }
  #     limits   = { cpu = "1",    memory = "2Gi" }
  #   }
  # }
  # eks_brainstore_writer_helm = {
  #   replicas = 1
  #   resources = {
  #     requests = { cpu = "1", memory = "2Gi" }
  #     limits   = { cpu = "2", memory = "4Gi" }
  #   }
  # }
}
