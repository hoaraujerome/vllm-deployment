variable "vpc_id" {
  description = "ID of the VPC that owns the route table."
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "ID of the subnet to associate with the route table."
  type        = string
  nullable    = false
}

variable "gateway_id" {
  description = "ID of the internet gateway or NAT gateway used for the default route."
  type        = string
  nullable    = false
}

variable "gateway_type" {
  description = "Gateway type for the default route: igw (internet gateway) or nat (NAT gateway)."
  type        = string

  validation {
    condition     = contains(["igw", "nat"], var.gateway_type)
    error_message = "gateway_type must be igw or nat."
  }
}
