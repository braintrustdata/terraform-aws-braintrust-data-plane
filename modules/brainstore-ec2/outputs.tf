output "dns_name" {
  description = "The DNS name of the Brainstore NLB"
  value       = aws_lb.brainstore.dns_name
}

output "writer_dns_name" {
  description = "The DNS name of the Brainstore writer NLB, if enabled"
  value       = one(aws_lb.brainstore_writer[*].dns_name)
}

output "fast_reader_dns_name" {
  description = "The DNS name of the Brainstore fast reader NLB, if enabled"
  value       = one(aws_lb.brainstore_fast_reader[*].dns_name)
}

output "port" {
  description = "The port used by Brainstore"
  value       = var.port
}

output "brainstore_elb_security_group_id" {
  description = "The ID of the security group for the Brainstore ELB"
  value       = aws_security_group.brainstore_elb.id
}

output "monitoring_targets" {
  description = "Brainstore targets keyed by stable role for monitoring integrations."
  value = merge(
    {
      reader = {
        asg_name      = aws_autoscaling_group.brainstore.name
        lb_arn_suffix = aws_lb.brainstore.arn_suffix
        tg_arn_suffix = aws_lb_target_group.brainstore.arn_suffix
      }
    },
    local.has_writer_nodes ? {
      writer = {
        asg_name      = aws_autoscaling_group.brainstore_writer[0].name
        lb_arn_suffix = aws_lb.brainstore_writer[0].arn_suffix
        tg_arn_suffix = aws_lb_target_group.brainstore_writer[0].arn_suffix
      }
    } : {},
    local.has_fast_reader_nodes ? {
      fast-reader = {
        asg_name      = aws_autoscaling_group.brainstore_fast_reader[0].name
        lb_arn_suffix = aws_lb.brainstore_fast_reader[0].arn_suffix
        tg_arn_suffix = aws_lb_target_group.brainstore_fast_reader[0].arn_suffix
      }
    } : {},
  )
}
