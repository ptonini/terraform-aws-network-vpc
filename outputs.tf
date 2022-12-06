output "this" {
  value = aws_vpc.this
}

output "public_subnets" {
  value = [for s in module.public_subnets : s.this]
}

output "private_subnets" {
  value = [for s in module.private_subnets : s.this]
}

output "peering_requests" {
  value = aws_vpc_peering_connection.this
}