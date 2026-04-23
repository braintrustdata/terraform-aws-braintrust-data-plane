# tflint-ignore-file: terraform_module_pinned_source

locals {
  # Each deployment in the same AWS account must have a unique name.
  # Do not change this after deployment. RDS and S3 resources can not be
  # renamed. Max 18 characters, lowercase letters, numbers, and hyphens only.
  #
  # Declared as a local so `provider.tf` can derive the EKS cluster name
  # from it without a duplicate literal.
  deployment_name = "braintrust"
}

module "braintrust-data-plane" {
  source = "../../"
  # For production use, pin to a released version:
  # source = "github.com/braintrustdata/terraform-braintrust-data-plane?ref=vX.Y.Z"

  ### This example is configured for a Terraform-managed EKS Auto Mode
  ### deployment. All the Braintrust K8s workloads run in-cluster and are
  ### deployed via Helm.
  ###
  ### IMPORTANT — two-step apply required on first deployment. The
  ### kubernetes and helm providers need a `data.aws_eks_cluster` lookup
  ### in `provider.tf` to succeed, which requires the EKS cluster to
  ### already exist. Target the cluster submodule first, then do a plain
  ### apply for everything else:
  ###
  ###   # Step 1: bring up the EKS cluster (pulls in VPC and subnet
  ###   #         dependencies via -target).
  ###   terraform apply '-target=module.braintrust-data-plane.module.eks_cluster[0]'
  ###
  ###   # Step 2: everything else — remaining AWS infra (RDS, Redis,
  ###   #         S3, KMS, services_common IAM/SGs) and the K8s layer
  ###   #         (namespace, Secret, Pod Identity associations,
  ###   #         NodeClass/NodePool, Braintrust Helm release).
  ###   terraform apply
  ###
  ### (Single-quote the `-target` so zsh doesn't glob-expand the `[0]`.)
  ###
  ### The kubernetes and helm providers use `exec { aws eks get-token }`
  ### auth in provider.tf, so step 2's runtime isn't bounded by any
  ### token TTL — safe for long applies (e.g. slow first-time image
  ### pulls) and for leaving the approval prompt open. Requires the AWS
  ### CLI on the runner.

  deployment_name = local.deployment_name

  # Add your organization name from the Braintrust UI here
  braintrust_org_name = ""

  # Brainstore license key (from the Braintrust UI in Settings > Data Plane).
  brainstore_license_key = var.brainstore_license_key

  ### EKS deployment mode
  # use_deployment_mode_external_eks = true disables the Lambda, EC2
  # Brainstore, and Lambda-based ingress submodules. create_eks_cluster = true
  # then provisions an EKS Auto Mode cluster and deploys the Helm chart on it.
  use_deployment_mode_external_eks = true
  create_eks_cluster               = true

  # Version of the Braintrust Helm chart to deploy. Pin to an exact version
  # so chart upgrades are deliberate rather than silent — the contract
  # between this module and the chart (see CONTRACT.md) depends on
  # chart-version-specific names, keys, and values schema.
  helm_chart_version = "6.1.0"

  # Kubernetes namespace for Braintrust workloads. Created by the module.
  eks_namespace = "braintrust"

  # Kubernetes version for the EKS cluster.
  eks_kubernetes_version = "1.31"

  # EC2 instance families Auto Mode's Karpenter picks from for the
  # Brainstore NodePool. Must be NVMe-backed (*d.*) — Brainstore caches
  # to local SSD. Graviton by default (matches EC2 Brainstore defaults).
  # eks_brainstore_nodepool_instance_families = ["c8gd", "c7gd", "m7gd"]

  ### Quarantine VPC
  # Disabled in EKS mode — it's used by the Lambda-based user-function
  # execution path, which is not part of the EKS deployment.
  enable_quarantine_vpc = false

  ### Postgres
  postgres_instance_type    = "db.r8g.2xlarge"
  postgres_storage_size     = 1000
  postgres_max_storage_size = 10000
  postgres_storage_type     = "gp3"

  # IOPS and throughput can only be specified for postgres gp3 when storage
  # is >= 400 GB. Below that, RDS rejects CreateDBInstance with
  # `InvalidParameterCombination`. Values below are the tuned defaults for a
  # 1000 GB production deployment; if you downsize `postgres_storage_size`
  # under 400 GB (e.g. for a sandbox), comment these two out — gp3 baseline
  # of 3000 IOPS / 125 MiB/s applies automatically.
  postgres_storage_iops       = 15000
  postgres_storage_throughput = 500

  postgres_version                    = "15"
  postgres_auto_minor_version_upgrade = true

  ### Redis
  redis_instance_type = "cache.t4g.medium"
  redis_version       = "7.0"

  ### Brainstore chart configuration
  # WAL footer version and no-PG mode. These pass through to the chart as
  # top-level values.
  #
  # WARNING: skip_pg_for_brainstore_objects = "all" is a one-way operation
  # once applied. It is safe for fresh deployments but can cause data loss
  # or downtime if applied to an existing deployment incorrectly. See the
  # upgrade guide before enabling on an existing deployment.
  brainstore_wal_footer_version  = "v3"
  skip_pg_for_brainstore_objects = "all"

  ### Optional: structured Helm overrides for sandbox-sized deployments.
  ### Uncomment and adjust if the chart's production-default resources
  ### are too large for your test cluster.
  # eks_api_helm = {
  #   replicas = 1
  #   resources = {
  #     requests = { cpu = "500m", memory = "1Gi" }
  #     limits   = { cpu = "1",    memory = "2Gi" }
  #   }
  # }
  # eks_brainstore_reader_helm = {
  #   replicas = 1
  #   resources = {
  #     requests = { cpu = "1", memory = "2Gi" }
  #     limits   = { cpu = "2", memory = "4Gi" }
  #   }
  # }
  # eks_brainstore_fastreader_helm = {
  #   replicas = 1
  #   resources = {
  #     requests = { cpu = "1", memory = "2Gi" }
  #     limits   = { cpu = "2", memory = "4Gi" }
  #   }
  # }
  # eks_brainstore_writer_helm = {
  #   replicas = 1
  #   resources = {
  #     requests = { cpu = "1", memory = "2Gi" }
  #     limits   = { cpu = "2", memory = "4Gi" }
  #   }
  # }

  ### Optional: raw-YAML escape hatch for chart settings the structured
  ### variables don't cover (annotations, labels, probes, tolerations,
  ### image pins, etc.). Merged in last — wins over the rendered template
  ### and any structured overrides above.
  # eks_helm_chart_extra_values = <<-YAML
  #   api:
  #     annotations:
  #       configmap:
  #         myorg.example.com/owner: "platform-team"
  # YAML

  ### Tagging
  # Optionally add any custom AWS tags you want to apply to all resources.
  # custom_tags = {
  #   CustomTagKey = "SomeValue"
  # }
}
