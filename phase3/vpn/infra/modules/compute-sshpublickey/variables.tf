variable "public_key_path" {
  description = "Path to the SSH public key file."
  type        = string
  nullable    = false
}

variable "tag_prefix" {
  description = "Prefix for the EC2 key pair name (unique per account/region)."
  type        = string
  nullable    = false
}
