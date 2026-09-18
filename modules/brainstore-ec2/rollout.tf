resource "terraform_data" "rollout_complete" {
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
