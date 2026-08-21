variable "subnet_id" {
  description = "ID of the subnet for the EC2 Instance Connect Endpoint."
  type        = string
  nullable    = false
}

variable "security_group_ids" {
  description = "Security group IDs attached to the endpoint."
  type        = set(string)
  nullable    = false
}

variable "tag_prefix" {
  description = "Prefix for the endpoint Name tag."
  type        = string
  nullable    = false
}
