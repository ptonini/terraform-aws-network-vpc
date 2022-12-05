locals {
    available_az_count = length(var.zone_names)
}

resource "aws_vpc" "this" {
    cidr_block = var.ipv4_cidr
    assign_generated_ipv6_cidr_block = true
    enable_dns_hostnames = true
    enable_dns_support = true
    instance_tenancy = "default"
    tags = {
        Name = var.name
    }
}


# Default security group

resource "aws_default_security_group" "this" {
    vpc_id = aws_vpc.this.id
    ingress {
        protocol = -1
        self = true
        from_port = 0
        to_port = 0
        cidr_blocks = [var.ipv4_cidr]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}


# Peering connections

resource "aws_vpc_peering_connection" "this" {
    for_each = var.peering_requests
    peer_owner_id = each.value.account_id
    peer_vpc_id = each.value.vpc.id
    vpc_id = aws_vpc.this.id
}

resource "aws_vpc_peering_connection_accepter" "this" {
    for_each = var.peering_acceptors
    vpc_peering_connection_id = each.value.peering_request.id
    auto_accept = true
}


# Internet Gateways

resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id
}


# Main route table

resource "aws_route_table" "main" {
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
    route_table_id = aws_route_table.main.id
}


# NAt Gateway

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


# Network flow logs

module "bucket" {
    source = "ptonini/s3-bucket/aws"
    version = "~> 1.0.0"
    name = var.flow_logs_bucket_name
    bucket_policy_statements = [
        {
            Sid = "AWSLogDeliveryWrite"
            Effect = "Allow"
            Principal = {
                Service = "delivery.logs.amazonaws.com"
            }
            Action = "s3:PutObject"
            Resource = "arn:aws:s3:::${var.flow_logs_bucket_name}/AWSLogs/${var.account_id}/*"
            Condition = {
                StringEquals = {
                    "s3:x-amz-acl" = "bucket-owner-full-control"
                    "aws:SourceAccount" = var.account_id
                }
                ArnLike = {
                    "aws:SourceArn" = "arn:aws:logs:${var.region}:${var.account_id}:*"
                }
            }
        },
        {
            Sid = "AWSLogDeliveryCheck"
            Effect = "Allow"
            Principal = {
                Service = "delivery.logs.amazonaws.com"
            }
            Action = [
                "s3:GetBucketAcl",
                "s3:ListBucket"
            ]
            Resource = "arn:aws:s3:::${var.flow_logs_bucket_name}"
            Condition = {
                StringEquals = {
                    "aws:SourceAccount" = var.account_id
                },
                ArnLike = {
                    "aws:SourceArn" = "arn:aws:logs:${var.region}:${var.account_id}:*"
                }
            }
        }
    ]
}

resource "aws_flow_log" "this" {
    log_destination = module.bucket.this.arn
    log_destination_type = "s3"
    traffic_type = "ALL"
    vpc_id = aws_vpc.this.id
    destination_options {
        file_format = "parquet"
        per_hour_partition = true
    }
}