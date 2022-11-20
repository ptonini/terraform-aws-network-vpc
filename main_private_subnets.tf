resource "aws_eip" "nat_gtw" {
    count = var.private ? 1 : 0
    vpc = true
}

resource "aws_nat_gateway" "this" {
    count = var.private ? 1 : 0
    allocation_id = aws_eip.nat_gtw.0.id
    subnet_id = aws_subnet.public.0.id
}

resource "aws_route_table" "private_subnets" {
    count = var.private ? 1 : 0
    vpc_id = aws_vpc.this.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.this.0.id
    }
    dynamic "route" {
        for_each = var.peering_requests
        content {
            cidr_block = route.value.vpc.cidr_block
            vpc_peering_connection_id = aws_vpc_peering_connection.this[route.key].id
        }
    }
    dynamic "route" {
        for_each = var.peering_acceptors
        content {
            cidr_block = route.value.vpc.cidr_block
            vpc_peering_connection_id = route.value.peering_request.id
        }
    }

}

resource "aws_subnet" "private" {
    count = var.private ? local.available_az_count : 0
    vpc_id = aws_vpc.this.id
    cidr_block = cidrsubnet(var.ipv4_cidr, var.subnet_newbits, count.index + local.available_az_count)
    availability_zone = data.aws_availability_zones.this.names[count.index]
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