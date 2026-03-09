# When security group became optional (count), state must be moved to the indexed resource.
moved {
  from = aws_security_group.elasticache
  to   = aws_security_group.elasticache[0]
}
moved {
  from = aws_vpc_security_group_egress_rule.elasticache_allow_egress_all
  to   = aws_vpc_security_group_egress_rule.elasticache_allow_egress_all[0]
}
