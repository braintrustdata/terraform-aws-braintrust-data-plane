locals {
  api_toleration = {
    key      = "dedicated"
    operator = "Equal"
    value    = "services"
    effect   = "NoSchedule"
  }

  brainstore_toleration = {
    key      = "dedicated"
    operator = "Equal"
    value    = "brainstore"
    effect   = "NoSchedule"
  }

  brainstore_reader_node_selector = var.use_auto_mode ? tomap({
    "karpenter.sh/nodepool" = "brainstore-reader"
    }) : tomap({
    role = "brainstore-reader"
  })

  brainstore_writer_node_selector = var.use_auto_mode ? tomap({
    "karpenter.sh/nodepool" = "brainstore-writer"
    }) : tomap({
    role = "brainstore-writer"
  })

  api_base = {
    service = {
      type = "LoadBalancer"
    }
    annotations = {
      service = merge(
        {
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internal"
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance"
          "service.beta.kubernetes.io/aws-load-balancer-security-groups" = var.nlb_security_group_id
          "service.beta.kubernetes.io/aws-load-balancer-name"            = var.nlb_name
        },
        var.prepare_for_destroy ? {
          # Shorten target deregistration so destroy is less likely to stall on
          # AWS Load Balancer Controller finalizers.
          "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes" = "deregistration_delay.timeout_seconds=0"
        } : {}
      )
    }
    serviceAccount = {
      name       = var.api_service_account_name
      awsRoleArn = var.api_handler_role_arn
    }
  }

  # Emitted as a separate Helm values layer so compact() drops it cleanly in Auto Mode,
  # avoiding Terraform object type-consistency errors from conditional merges.
  api_scheduling_yaml = var.use_auto_mode ? "" : yamlencode({
    api = {
      nodeSelector = { role = "services" }
      tolerations  = [local.api_toleration]
    }
  })

  brainstore_base = {
    serviceAccount = {
      name       = var.brainstore_service_account_name
      awsRoleArn = var.brainstore_iam_role_arn
    }
    reader = {
      nodeSelector = local.brainstore_reader_node_selector
      tolerations  = [local.brainstore_toleration]
    }
    fastreader = {
      nodeSelector = local.brainstore_reader_node_selector
      tolerations  = [local.brainstore_toleration]
    }
    writer = {
      nodeSelector = local.brainstore_writer_node_selector
      tolerations  = [local.brainstore_toleration]
    }
  }

  api_structured_override = merge(
    var.api_helm.replicas != null ? { replicas = var.api_helm.replicas } : {},
    var.api_helm.resources != null ? { resources = var.api_helm.resources } : {},
  )

  reader_structured_override = merge(
    var.brainstore_reader_helm.replicas != null ? { replicas = var.brainstore_reader_helm.replicas } : {},
    var.brainstore_reader_helm.resources != null ? { resources = var.brainstore_reader_helm.resources } : {},
  )

  fastreader_structured_override = merge(
    var.brainstore_fastreader_helm.replicas != null ? { replicas = var.brainstore_fastreader_helm.replicas } : {},
    var.brainstore_fastreader_helm.resources != null ? { resources = var.brainstore_fastreader_helm.resources } : {},
  )

  writer_structured_override = merge(
    var.brainstore_writer_helm.replicas != null ? { replicas = var.brainstore_writer_helm.replicas } : {},
    var.brainstore_writer_helm.resources != null ? { resources = var.brainstore_writer_helm.resources } : {},
  )

  brainstore_structured_override = merge(
    length(local.reader_structured_override) > 0 ? { reader = local.reader_structured_override } : {},
    length(local.fastreader_structured_override) > 0 ? { fastreader = local.fastreader_structured_override } : {},
    length(local.writer_structured_override) > 0 ? { writer = local.writer_structured_override } : {},
  )

  helm_structured_overrides = merge(
    length(local.api_structured_override) > 0 ? { api = local.api_structured_override } : {},
    length(local.brainstore_structured_override) > 0 ? { brainstore = local.brainstore_structured_override } : {},
  )

  helm_base_values = {
    global = {
      orgName         = var.braintrust_org_name
      createNamespace = false
      namespace       = var.namespace
    }

    cloud = "aws"

    skipPgForBrainstoreObjects = var.skip_pg_for_brainstore_objects
    brainstoreWalFooterVersion = var.brainstore_wal_footer_version

    objectStorage = {
      aws = {
        brainstoreBucket = var.brainstore_bucket_name
        responseBucket   = var.response_bucket_name
        codeBundleBucket = var.code_bundle_bucket_name
      }
    }

    api        = local.api_base
    brainstore = local.brainstore_base
  }

  helm_values_documents = compact([
    local.helm_base_values_yaml,
    local.api_scheduling_yaml,
    local.helm_structured_overrides_yaml,
    var.helm_chart_extra_values,
  ])

  helm_values_yaml = join("\n---\n", local.helm_values_documents)

  helm_base_values_yaml          = yamlencode(local.helm_base_values)
  helm_structured_overrides_yaml = length(local.helm_structured_overrides) > 0 ? yamlencode(local.helm_structured_overrides) : ""
}
