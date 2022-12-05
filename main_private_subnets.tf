resource "aws_subnet" "private" {
    count = var.private ? local.available_az_count : 0
    vpc_id = aws_vpc.this.id
    cidr_block = cidrsubnet(var.ipv4_cidr, var.subnet_newbits, count.index + local.available_az_count)
    availability_zone = var.zone_names[count.index]
    map_public_ip_on_launch = false
    tags = merge({
        Name = "${var.name}-private_${count.index}"
    }, var.subnet_tags)
}

resource "aws_route_table_association" "private" {
    count = var.private ? local.available_az_count : 0
    subnet_id = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.private_subnets.0.id
}