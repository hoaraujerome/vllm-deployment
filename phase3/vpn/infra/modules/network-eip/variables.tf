variable "tag_prefix" {
  description = "Prefix for the EIP Name tag."
  type        = string
  nullable    = false
}

variable "instance_id" {
  description = "EC2 instance ID to associate with the EIP."
  type        = string
  nullable    = false
}
