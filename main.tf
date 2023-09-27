locals {
  zone_count = length(var.zones)
  peering_routes = merge(
    { for k, v in var.peering_requests : "${k}_request" => {
      cidr_block    = v.vpc.cidr_block
      connection_id = aws_vpc_peering_connection.this[k].id
      }
    },
    { for k, v in var.peering_acceptors : "${k}_acceptor" => {
      cidr_block    = v.vpc.cidr_block
      connection_id = v.peering_request.id
      }
    }
  )
}

resource "aws_vpc" "this" {
  cidr_block                       = var.ipv4_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true
  instance_tenancy                 = "default"
  tags = {
    Name = var.name
  }
  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  ingress {
    protocol    = -1
    self        = true
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.ipv4_cidr]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}

resource "aws_vpc_peering_connection" "this" {
  for_each      = var.peering_requests
  peer_owner_id = each.value.account_id
  peer_vpc_id   = each.value.vpc.id
  vpc_id        = aws_vpc.this.id
}

resource "aws_vpc_peering_connection_accepter" "this" {
  for_each                  = var.peering_acceptors
  vpc_peering_connection_id = each.value.peering_request.id
  auto_accept               = true
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.this.id
  }
  dynamic "route" {
    for_each = var.network_interface_routes
    content {
      cidr_block           = route.value.cidr_block
      network_interface_id = route.value.network_interface_id
    }
  }
  dynamic "route" {
    for_each = local.peering_routes
    content {
      cidr_block                = route.value["cidr_block"]
      vpc_peering_connection_id = route.value["connection_id"]
    }
  }
  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}

resource "aws_main_route_table_association" "public" {
  vpc_id         = aws_vpc.this.id
  route_table_id = aws_route_table.main.id
}

module "public_subnets" {
  source                  = "ptonini/networking-subnet/aws"
  version                 = "~> 1.0.0"
  count                   = local.zone_count
  name                    = "${var.name}-public${format("%04.0f", count.index + 1)}"
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.ipv4_cidr, var.subnet_newbits, count.index)
  availability_zone       = var.zones[count.index]
  map_public_ip_on_launch = true
}

module "nat_gateway" {
  source         = "ptonini/networking-nat-gateway/aws"
  version        = "~> 1.0.1"
  count          = var.private_subnets ? 1 : 0
  vpc_id         = aws_vpc.this.id
  subnet_id      = module.public_subnets[0].this.id
  peering_routes = local.peering_routes
}

module "private_subnets" {
  source            = "ptonini/networking-subnet/aws"
  version           = "~> 1.0.0"
  count             = var.private_subnets ? local.zone_count : 0
  name              = "${var.name}-private${format("%04.0f", count.index + 1)}"
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.ipv4_cidr, var.subnet_newbits, count.index + local.zone_count)
  availability_zone = var.zones[count.index]
  route_table_ids   = [module.nat_gateway[0].route_table_id]
}


# Network flow logs

module "bucket" {
  source  = "ptonini/s3-bucket/aws"
  version = "~> 2.0.0"
  count   = var.flow_logs_bucket_name == null ? 0 : 1
  name    = var.flow_logs_bucket_name
  bucket_policy_statements = [
    {
      Sid    = "AWSLogDeliveryWrite"
      Effect = "Allow"
      Principal = {
        Service = "delivery.logs.amazonaws.com"
      }
      Action   = "s3:PutObject"
      Resource = "arn:aws:s3:::${var.flow_logs_bucket_name}/AWSLogs/${var.account_id}/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl"      = "bucket-owner-full-control"
          "aws:SourceAccount" = var.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:logs:${var.region}:${var.account_id}:*"
        }
      }
    },
    {
      Sid    = "AWSLogDeliveryCheck"
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
  count                = var.flow_logs_bucket_name == null ? 0 : 1
  log_destination      = module.bucket[0].this.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id
  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
  }
}