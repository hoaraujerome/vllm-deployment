variable "vpc_id" {
  description = "ID of the VPC to attach the internet gateway to."
  type        = string
  nullable    = false
}

variable "tag_prefix" {
  description = "Prefix for the internet gateway Name tag."
  type        = string
  default     = ""
  nullable    = false
}
