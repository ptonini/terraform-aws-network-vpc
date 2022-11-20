variable "name" {}

variable "flow_logs_bucket_name" {}

variable "ipv4_cidr" {}

variable "subnet_newbits" {}

variable "subnet_tags" {
  default = {}
}

variable "public" {
  default = true
}

variable "private" {
  default = true
}

variable "peering_requests" {
  default = {}
  type = map(object({
    account_id = string
    vpc = object({
      id = string
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
      id = string
      cidr_block = string
    })
  }))
}

variable "vpn_connections" {
  default = {}
}

variable "region" {
  default = "us-east-1"
}

variable "account_id" {}