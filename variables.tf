variable "name" {}

variable "ipv4_cidr" {}

variable "zones" {
  type = list(string)
}

variable "subnet_newbits" {}

variable "private_subnets" {
  default = false
}

variable "isolated_subnets" {
  default = false
}

variable "default_security_group" {
  type = object({
    ingress_rules = optional(map(object({
      from_port        = number
      to_port          = optional(number)
      protocol         = optional(string)
      cidr_blocks      = optional(set(string))
      ipv6_cidr_blocks = optional(set(string))
      prefix_list_ids  = optional(set(string))
      security_groups  = optional(set(string))
      self             = optional(bool)
    })), { self = { protocol = -1, from_port = 0, self = true } })
    egress_rules = optional(map(object({
      from_port        = number
      to_port          = optional(number)
      protocol         = optional(string)
      cidr_blocks      = optional(set(string))
      ipv6_cidr_blocks = optional(set(string))
      prefix_list_ids  = optional(set(string))
      security_groups  = optional(set(string))
      self             = optional(bool)
    })), { all = { protocol = -1, from_port = 0, cidr_blocks = ["0.0.0.0/0"], ipv6_cidr_blocks = ["::/0"] } })
  })
  default = {}
}

variable "network_interface_routes" {
  default = {}
  type = map(object({
    cidr_block           = string
    network_interface_id = string
  }))
}

variable "gateway_routes" {
  default = {}
  type = map(object({
    cidr_block = string
    gateway_id = string
  }))
}

variable "peering_requests" {
  default = {}
  type = map(object({
    account_id = string
    vpc = object({
      id         = string
      cidr_block = string
    })
  }))
}

variable "peering_acceptors" {
  default = {}
  type = map(object({
    peering_request = object({
      id = string
    })
    vpc = object({
      id         = string
      cidr_block = string
    })
  }))
}

variable "vpc_endpoints" {
  type = map(object({
    service_name = string
    type         = string
  }))
  default = {}
}

variable "flow_logs" {
  type = object({
    bucket_name          = optional(string)
    bucket_kms_key_id    = optional(string)
    log_destination      = optional(string)
    log_destination_type = optional(string, "s3")
    traffic_type         = optional(string, "ALL")
    destination_options = optional(object({
      file_format        = optional(string, "parquet")
      per_hour_partition = optional(bool, true)
    }), {})
  })
  default = null
}
