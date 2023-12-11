locals {
  zone_count = length(var.zones)
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block                       = var.cidr_block
  assign_generated_ipv6_cidr_block = true
  enable_dns_hostnames             = true
  enable_dns_support               = true
  instance_tenancy                 = "default"
  tags = {
    Name = var.name
  }

  lifecycle {
    ignore_changes = [
      tags["business_unit"],
      tags["product"],
      tags["env"],
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
      tags["business_unit"],
      tags["product"],
      tags["env"],
      tags_all
    ]
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.name}-gtw"
  }

  lifecycle {
    ignore_changes = [
      tags["business_unit"],
      tags["product"],
      tags["env"],
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

module "main_route_table" {
  source           = "ptonini/networking-route-table/aws"
  version          = "~> 1.1.0"
  name             = "${var.name}-main"
  vpc              = aws_vpc.this
  main_route_table = true
  routes = merge(
    { public = { cidr_block = "0.0.0.0/0", gateway_id = aws_internet_gateway.this.id } },
    { public-ivp6 = { ipv6_cidr_block = "::/0", gateway_id = aws_internet_gateway.this.id } },
    { for k, v in var.peering_requests : "${k}_request" => { cidr_block = v.vpc.cidr_block, vpc_peering_connection_id = aws_vpc_peering_connection.this[k].id } },
    { for k, v in var.peering_acceptors : "${k}_acceptor" => { cidr_block = v.vpc.cidr_block, vpc_peering_connection_id = v.peering_request.id, } },
    var.main_table_routes
  )
}

module "log_bucket" {
  source  = "ptonini/s3-bucket/aws"
  version = "~> 2.2.0"
  count   = var.flow_logs.bucket_name == null ? 0 : 1
  name    = var.flow_logs.bucket_name
  server_side_encryption = {
    kms_master_key_id = var.flow_logs.bucket_kms_key_id
  }
  bucket_policy_statements = [
    {
      Sid    = "AWSLogDeliveryWrite"
      Effect = "Allow"
      Principal = {
        Service = "delivery.logs.amazonaws.com"
      }
      Action   = "s3:PutObject"
      Resource = "arn:aws:s3:::${var.flow_logs.bucket_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl"      = "bucket-owner-full-control"
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
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
      Resource = "arn:aws:s3:::${var.flow_logs.bucket_name}"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        },
        ArnLike = {
          "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }
  ]
}

resource "aws_flow_log" "this" {
  count                = var.flow_logs == null ? 0 : 1
  log_destination      = coalesce(var.flow_logs.log_destination, module.log_bucket[0].this.arn)
  log_destination_type = var.flow_logs.log_destination_type
  traffic_type         = var.flow_logs.traffic_type
  vpc_id               = aws_vpc.this.id

  destination_options {
    file_format        = var.flow_logs.destination_options.file_format
    per_hour_partition = var.flow_logs.destination_options.per_hour_partition
  }
}