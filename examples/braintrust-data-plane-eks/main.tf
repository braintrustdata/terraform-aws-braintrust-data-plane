# tflint-ignore-file: terraform_module_pinned_source

# Example: Terraform-managed Braintrust data plane on EKS Auto Mode.
#
# All logic (EKS cluster + Auto Mode config, CloudFront, NLB, Kubernetes
# namespace + Secret, Pod Identity associations, custom NodePool for
# Brainstore NVMe, Braintrust Helm release) lives in the module. This
# example is just configuration.
#
# IMPORTANT — two-step apply required on first deployment:
#
#   Step 1: terraform apply -target=module.braintrust.module.eks_cluster[0]
#   Step 2: terraform apply
#
# Step 1 creates the EKS cluster so the kubernetes and helm providers in
# provider.tf can resolve its endpoint. Step 2 plans the
# kubernetes_manifest resources (which require Auto Mode's NodeClass /
# NodePool CRDs to exist on the cluster) and deploys everything else.

module "braintrust" {
  source = "../../"
  # For production use, pin to a released version:
  # source = "github.com/braintrustdata/terraform-braintrust-data-plane?ref=vX.Y.Z"

  deployment_name        = var.deployment_name
  braintrust_org_name    = var.braintrust_org_name
  brainstore_license_key = var.brainstore_license_key

  # EKS deployment mode — disables Lambda, EC2 Brainstore, and Lambda-based ingress.
  use_deployment_mode_external_eks = true
  # Create and manage the EKS Auto Mode cluster with Terraform.
  create_eks_cluster = true

  eks_namespace      = var.eks_namespace
  helm_chart_version = var.helm_chart_version

  brainstore_wal_footer_version  = var.brainstore_wal_footer_version
  skip_pg_for_brainstore_objects = var.skip_pg_for_brainstore_objects

  # Disable quarantine VPC (Lambda-based, not relevant for EKS mode).
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

  ### Optional: structured helm overrides for sandbox-sized deployments.
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

  ### Optional: raw-YAML escape hatch for chart settings not covered by
  ### structured variables (annotations, labels, probes, tolerations,
  ### image pins, etc.). Merged in last — wins over the rendered template
  ### and any structured overrides above.
  # eks_helm_chart_extra_values = <<-YAML
  #   api:
  #     annotations:
  #       configmap:
  #         myorg.example.com/owner: "platform-team"
  # YAML
}
