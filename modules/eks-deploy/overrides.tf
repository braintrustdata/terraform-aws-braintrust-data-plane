# Build a Helm values YAML blob from the structured override variables.
# Only fields the caller actually set are emitted so unset overrides fall
# back to chart defaults (null values from `optional()` get dropped).
locals {
  _api_override = merge(
    var.api_helm.replicas != null ? { replicas = var.api_helm.replicas } : {},
    var.api_helm.resources != null ? { resources = var.api_helm.resources } : {},
  )
  _reader_override = merge(
    var.brainstore_reader_helm.replicas != null ? { replicas = var.brainstore_reader_helm.replicas } : {},
    var.brainstore_reader_helm.resources != null ? { resources = var.brainstore_reader_helm.resources } : {},
  )
  _fastreader_override = merge(
    var.brainstore_fastreader_helm.replicas != null ? { replicas = var.brainstore_fastreader_helm.replicas } : {},
    var.brainstore_fastreader_helm.resources != null ? { resources = var.brainstore_fastreader_helm.resources } : {},
  )
  _writer_override = merge(
    var.brainstore_writer_helm.replicas != null ? { replicas = var.brainstore_writer_helm.replicas } : {},
    var.brainstore_writer_helm.resources != null ? { resources = var.brainstore_writer_helm.resources } : {},
  )

  _brainstore_override = merge(
    length(local._reader_override) > 0 ? { reader = local._reader_override } : {},
    length(local._fastreader_override) > 0 ? { fastreader = local._fastreader_override } : {},
    length(local._writer_override) > 0 ? { writer = local._writer_override } : {},
  )

  _helm_overrides = merge(
    length(local._api_override) > 0 ? { api = local._api_override } : {},
    length(local._brainstore_override) > 0 ? { brainstore = local._brainstore_override } : {},
  )

  helm_structured_overrides_yaml = length(local._helm_overrides) > 0 ? yamlencode(local._helm_overrides) : ""
}
