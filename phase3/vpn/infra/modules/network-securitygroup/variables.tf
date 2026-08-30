variable "vpc_id" {
  description = "ID of the VPC that owns the security groups."
  type        = string
  nullable    = false
}

variable "names" {
  description = "Logical names for security groups to create."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.names) > 0
    error_message = "At least one security group name must be provided."
  }
}

variable "tag_prefix" {
  description = "Prefix for AWS security group names and Name tags."
  type        = string
  nullable    = false
}
