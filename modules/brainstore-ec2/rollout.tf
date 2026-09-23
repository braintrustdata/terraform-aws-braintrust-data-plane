resource "terraform_data" "rollout_complete" {
  # This waits for healthy replacement capacity. With create_before_destroy,
  # Terraform can update dependents before deleting the deposed ASGs, so a
  # separate Brainstore apply is required when API updates must wait for deletion.
  triggers_replace = compact([
    aws_autoscaling_group.brainstore.id,
    one(aws_autoscaling_group.brainstore_writer[*].id),
    one(aws_autoscaling_group.brainstore_fast_reader[*].id),
  ])

  depends_on = [
    aws_autoscaling_group.brainstore,
    aws_autoscaling_group.brainstore_writer,
    aws_autoscaling_group.brainstore_fast_reader,
  ]
}
