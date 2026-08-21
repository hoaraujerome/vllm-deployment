variable "subnet_id" {
  description = "ID of the subnet where the NAT gateway is created (must route to an internet gateway)."
  type        = string
  nullable    = false
}

variable "tag_prefix" {
  description = "Prefix for NAT gateway and EIP Name tags."
  type        = string
  default     = ""
  nullable    = false
}
