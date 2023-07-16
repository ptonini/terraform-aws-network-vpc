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

variable "network_interface_routes" {
  default = {}
  type = map(object({
    cidr_block = string
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

variable "flow_logs_bucket_name" {
  default = null
}