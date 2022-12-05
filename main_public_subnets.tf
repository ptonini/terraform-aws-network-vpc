resource "aws_subnet" "public" {
    count = local.available_az_count
    vpc_id = aws_vpc.this.id
    cidr_block = cidrsubnet(var.ipv4_cidr, var.subnet_newbits, count.index)
    availability_zone = var.zone_names[count.index]
    map_public_ip_on_launch = true
    tags = merge(
        { Name = "${var.name}-public_${count.index}" },
        var.subnet_tags
    )
}

