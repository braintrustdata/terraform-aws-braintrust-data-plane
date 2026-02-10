resource "aws_iam_instance_profile" "brainstore" {
  name = "${var.deployment_name}-brainstore${local.name_suffix}-instance-profile"
  role = var.brainstore_iam_role_name

  tags = local.common_tags
}
