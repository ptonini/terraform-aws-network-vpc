output "this" {
  value = aws_vpc.this
}

output "default_security_group_id" {
  value = aws_default_security_group.this.id
}

output "public_subnet_ids" {
  value = [for s in module.public_subnets : s.this.id]
}

output "private_subnet_ids" {
  value = [for s in module.private_subnets : s.this.id]
}

output "isolated_subnet_ids" {
  value = [for s in module.isolated_subnets : s.this.id]
}

output "peering_requests" {
  value = aws_vpc_peering_connection.this
}