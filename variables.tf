variable "name" {}

variable "account_id" {}

variable "region" {}

variable "zones" {
  type = list(string)
}

variable "ipv4_cidr" {}

variable "subnet_newbits" {}

variable "private_subnets" {
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
    })), { self = { protocol = -1, self = true, from_port = 0, to_port = 0, } })
    egress_rules = optional(map(object({
      from_port        = number
      to_port          = optional(number)
      protocol         = optional(string)
      cidr_blocks      = optional(set(string))
      ipv6_cidr_blocks = optional(set(string))
      prefix_list_ids  = optional(set(string))
      security_groups  = optional(set(string))
      self             = optional(bool)
    })), { all = { protocol = -1, from_port = 0, to_port = 0, cidr_blocks = ["0.0.0.0/0"], ipv6_cidr_blocks = ["::/0"] } })
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

variable "flow_logs_bucket_name" {
  default = null
}