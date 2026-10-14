# Adding count changes the address. These moves keep an existing third subnet
# and its route association in place on upgrade. A downgrade has no reverse
# move, so it recreates both resources.
moved {
  from = aws_subnet.private_subnet_3
  to   = aws_subnet.private_subnet_3[0]
}

moved {
  from = aws_route_table_association.private_subnet_3_association
  to   = aws_route_table_association.private_subnet_3_association[0]
}
