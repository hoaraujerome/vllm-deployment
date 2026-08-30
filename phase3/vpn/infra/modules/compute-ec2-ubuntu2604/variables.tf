variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched."
  type        = string
  nullable    = false
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with the instance."
  type        = bool
  default     = false
  nullable    = false
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the instance."
  type        = list(string)
  nullable    = false
}

variable "key_pair_name" {
  description = "SSH key pair name for instance access."
  type        = string
  nullable    = false
}

variable "user_data" {
  description = "User data script to run on instance launch."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags to apply to the instance."
  type        = map(string)
  default     = {}
  nullable    = false
}
