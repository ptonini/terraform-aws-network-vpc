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
      tags.business_unit,
      tags.product,
      tags.env,
      tags_all
    ]
  }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  dynamic "ingress" {
    for_each = var.default_security_group.ingress_rules
    content {
      from_port        = ingress.value.from_port
      to_port          = coalesce(ingress.value.to_port, ingress.value.from_port)
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      prefix_list_ids  = ingress.value.prefix_list_ids
      security_groups  = ingress.value.security_groups
      self             = ingress.value.self
    }
  }
  dynamic "egress" {
    for_each = var.default_security_group.egress_rules
    content {
      from_port        = egress.value.from_port
      to_port          = coalesce(egress.value.to_port, egress.value.from_port)
      protocol         = egress.value.protocol
      cidr_blocks      = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
      prefix_list_ids  = egress.value.prefix_list_ids
      security_groups  = egress.value.security_groups
      self             = egress.value.self
    }
  }
  lifecycle {
    ignore_changes = [
      tags.business_unit,
      tags.product,
      tags.env,
      tags_all
    ]
  }
}

# Subnets

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

# Routing

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
    for_each = var.gateway_routes
    content {
      cidr_block = route.value.cidr_block
      gateway_id = route.value.gateway_id
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
      tags.business_unit,
      tags.product,
      tags.env,
      tags_all
    ]
  }
}

resource "aws_main_route_table_association" "public" {
  vpc_id         = aws_vpc.this.id
  route_table_id = aws_route_table.main.id
}

# Internet gateways

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  lifecycle {
    ignore_changes = [
      tags.business_unit,
      tags.product,
      tags.env,
      tags_all
    ]
  }
}

module "nat_gateway" {
  source         = "ptonini/networking-nat-gateway/aws"
  version        = "~> 1.1.0"
  count          = var.private_subnets ? 1 : 0
  vpc_id         = aws_vpc.this.id
  subnet_id      = module.public_subnets[0].this.id
  peering_routes = local.peering_routes
}

# Peering connections

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

# VPC Endpoints

resource "aws_vpc_endpoint" "this" {
  for_each          = var.vpc_endpoints
  vpc_id            = aws_vpc.this.id
  service_name      = each.value.service_name
  vpc_endpoint_type = each.value.type
  subnet_ids        = var.private_subnets ? [for s in module.private_subnets : s.this.id] : [for s in module.public_subnets : s.this.id]

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