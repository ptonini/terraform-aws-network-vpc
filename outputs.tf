output "this" {
  value = aws_vpc.this
}

output "public_subnets" {
  value = aws_subnet.public
}

output "private_subnets" {
  value = aws_subnet.private
}

output "peering_requests" {
  value = aws_vpc_peering_connection.this
}