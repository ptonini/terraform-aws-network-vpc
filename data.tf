data "aws_availability_zones" "this" {
  state = "available"
}

data "aws_region" "this" {}

data "aws_caller_identity" "this" {}