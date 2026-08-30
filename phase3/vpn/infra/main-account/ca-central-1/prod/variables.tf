variable "aws_region" {
  description = "AWS region for Phase 3 WireGuard provisioning."
  type        = string
  default     = "ca-central-1"
  nullable    = false
}

variable "environment" {
  description = "Environment name for tagging."
  type        = string
  default     = "prod"
  nullable    = false
}

variable "wireguard_instance_type" {
  description = "EC2 instance type for WireGuard server."
  type        = string
  default     = "t4g.nano"
  nullable    = false
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for WireGuard EC2 access."
  type        = string
  nullable    = false
}
