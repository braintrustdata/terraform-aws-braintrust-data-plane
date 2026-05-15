#----------------------------------------------------------------------------------------------
# EKS Access Entries
#----------------------------------------------------------------------------------------------
locals {
  eks_access_policy_associations = {
    for association in flatten([
      for entry_name, entry in var.eks_access_entries : [
        for association_name, policy_association in entry.policy_associations : {
          key          = "${entry_name}-${association_name}"
          entry_name   = entry_name
          policy_arn   = policy_association.policy_arn
          access_scope = policy_association.access_scope
        }
      ]
    ]) : association.key => association
  }
}

resource "aws_eks_access_entry" "additional" {
  for_each = var.eks_access_entries

  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = each.value.principal_arn
  type              = each.value.type
  kubernetes_groups = each.value.kubernetes_groups
  user_name         = each.value.user_name

  tags = merge(
    {
      Name                     = "${var.deployment_name}-${each.key}"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

resource "aws_eks_access_policy_association" "additional" {
  for_each = local.eks_access_policy_associations

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.additional[each.value.entry_name].principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = each.value.access_scope.type
    namespaces = each.value.access_scope.type == "namespace" ? each.value.access_scope.namespaces : null
  }
}
