# tflint-ignore-file: terraform_module_pinned_source

module "braintrust-data-plane" {
  source = "../../"
  # For production use, pin to a released version:
  # source = "github.com/braintrustdata/terraform-braintrust-data-plane?ref=vX.Y.Z"

  ### Sandbox-sized EKS deployment.
  ### Smaller RDS / Redis / helm replicas than the production example,
  ### intended for cheap disposable testing. For a serious deployment use
  ### `examples/braintrust-data-plane-eks/` as the starting template.
  ###
  ### Single `terraform apply` brings up everything end to end.

  # Each deployment in the same AWS account must have a unique name.
  # Max 18 characters, lowercase letters, numbers, and hyphens only.
  deployment_name = "braintrust-eks-sb"

  # Add your organization name from the Braintrust UI here.
  braintrust_org_name = ""

  # Brainstore license key (from the Braintrust UI in Settings > Data Plane).
  brainstore_license_key = var.brainstore_license_key

  ### EKS deployment mode
  use_deployment_mode_external_eks = true
  create_eks_cluster               = true

  helm_chart_version = "6.1.0"

  # Kubernetes namespace for Braintrust workloads.
  eks_namespace = "braintrust"

  # Kubernetes version for the EKS cluster.
  eks_kubernetes_version = "1.31"

  # Disabled in EKS mode — it's used by the Lambda-based user-function
  # execution path.
  enable_quarantine_vpc = false

  ### Postgres (sandbox-sized)
  postgres_instance_type    = "db.r8g.large"
  postgres_storage_size     = 100
  postgres_max_storage_size = 500
  postgres_storage_type     = "gp3"
  # IOPS/throughput can only be specified when gp3 storage is >= 400 GB.
  # Nulled out for the 100 GB sandbox; gp3's baseline 3000 IOPS / 125 MiB/s
  # applies automatically.
  postgres_storage_iops               = null
  postgres_storage_throughput         = null
  postgres_version                    = "15"
  postgres_auto_minor_version_upgrade = true

  ### Redis (sandbox-sized)
  redis_instance_type = "cache.t4g.small"
  redis_version       = "7.0"

  ### Brainstore chart configuration.
  # WARNING: skip_pg_for_brainstore_objects = "all" is a one-way operation
  # once applied. Safe for a fresh sandbox deployment.
  brainstore_wal_footer_version  = "v3"
  skip_pg_for_brainstore_objects = "all"

  ### Helm values overrides — path to the sandbox values file alongside
  ### this main.tf. Shrinks replicas + resources for every chart component
  ### so it fits on a cheap cluster.
  eks_helm_values_file = "${path.module}/values.yaml"

  ### Tagging
  # custom_tags = {
  #   CustomTagKey = "SomeValue"
  # }
}
