locals {
  available_az_count = length(data.aws_availability_zones.this.names)
  allowed_ingress_cidr_blocks = [var.ipv4_cidr]
}