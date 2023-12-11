output "this" {
  value = aws_vpc.this
}

output "default_security_group_id" {
  value = aws_default_security_group.this.id
}

output "main_route_table_id" {
  value = module.main_route_table.this.id
}

output "peering_requests" {
  value = aws_vpc_peering_connection.this
}