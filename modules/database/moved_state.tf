# When security group became optional (count), state must be moved to the indexed resource.
moved {
  from = aws_security_group.rds
  to   = aws_security_group.rds[0]
}
moved {
  from = aws_vpc_security_group_egress_rule.rds_allow_egress_all
  to   = aws_vpc_security_group_egress_rule.rds_allow_egress_all[0]
}
