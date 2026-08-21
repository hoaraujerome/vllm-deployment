variable "ami_name_prefix" {
  description = "Name prefix for the custom kubeadm AMI built by phase2/images Packer (ami name vllm-phase2-kubeadm-<timestamp>, tag Name = prefix). most_recent available arm64 image matching this prefix is selected."
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "ID of the subnet for the EC2 instance."
  type        = string
  nullable    = false
}

variable "security_group_ids" {
  description = "Security group IDs attached to the instance."
  type        = set(string)
  nullable    = false
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair."
  type        = string
  nullable    = false
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t4g.small"
  nullable    = false
}

variable "tags" {
  description = "Tags applied to the EC2 instance (Name should be set by the caller)."
  type        = map(string)
  nullable    = false
}
