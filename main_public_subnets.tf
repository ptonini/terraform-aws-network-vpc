resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.this.id
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.this.id
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

resource "aws_main_route_table_association" "public" {
    vpc_id = aws_vpc.this.id
    route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "public" {
    count = local.available_az_count
    vpc_id = aws_vpc.this.id
    cidr_block = cidrsubnet(var.ipv4_cidr, var.subnet_newbits, count.index)
    availability_zone = data.aws_availability_zones.this.names[count.index]
    map_public_ip_on_launch = true
    tags = merge(
        { Name = "${var.name}-public_${count.index}" },
        var.subnet_tags
    )
}

