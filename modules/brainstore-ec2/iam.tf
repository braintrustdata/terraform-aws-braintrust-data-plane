resource "aws_iam_instance_profile" "brainstore" {
  name = "${var.deployment_name}-brainstore-instance-profile"
  role = var.brainstore_iam_role_name

  tags = local.common_tags
}
