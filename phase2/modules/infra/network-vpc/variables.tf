variable "vpc_ipv4_cidr_block" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  nullable    = false
}

variable "subnets" {
  description = "Subnets to create in the VPC, keyed by a stable logical name used in module outputs."
  type = map(object({
    ipv4_cidr_block         = string
    map_public_ip_on_launch = bool
  }))
  default = {}
}
