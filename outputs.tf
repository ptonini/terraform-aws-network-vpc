output "this" {
  value = aws_vpc.this
}

output "default_security_group_id" {
  value = aws_default_security_group.this.id
}

output "public_subnet_ids" {
  value = module.public_subnets[*].this.id
}

output "private_subnet_ids" {
  value = module.private_subnets[*].this.id
}

output "isolated_subnet_ids" {
  value = module.isolated_subnets[*].this.id
}

output "default_route_table_id" {
  value = aws_route_table.default.id
}

output "nat_route_table_id" {
  value = module.nat_gateway[*].route_table_id
}

output "isolated_route_table_id" {
  value = aws_route_table.isolated.id
}

output "peering_requests" {
  value = aws_vpc_peering_connection.this
}