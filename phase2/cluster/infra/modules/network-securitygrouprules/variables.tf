variable "security_group_id" {
  description = "ID of the security group to attach rules to."
  type        = string
  nullable    = false
}

variable "rules" {
  description = "Security group rules keyed by a stable logical name."
  type = map(object({
    description                  = optional(string)
    direction                    = string
    from_port                    = number
    to_port                      = number
    ip_protocol                  = string
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
  nullable = false

  validation {
    condition = alltrue([
      for rule in values(var.rules) : contains(["inbound", "outbound"], rule.direction)
    ])
    error_message = "Each rule direction must be inbound or outbound."
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) : rule.cidr_ipv4 != null || rule.referenced_security_group_id != null
    ])
    error_message = "Each rule must set cidr_ipv4 or referenced_security_group_id."
  }

  validation {
    condition = alltrue([
      for rule in values(var.rules) : !(rule.cidr_ipv4 != null && rule.referenced_security_group_id != null)
    ])
    error_message = "Each rule must set cidr_ipv4 or referenced_security_group_id, not both."
  }
}

variable "tag_prefix" {
  description = "Prefix for security group rule Name tags."
  type        = string
  nullable    = false
}
