resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = {
    for key, rule in var.rules : key => rule if rule.direction == "inbound"
  }

  description                  = each.value.description
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = var.security_group_id

  tags = {
    Name = "${var.tag_prefix}${each.key}"
  }
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = {
    for key, rule in var.rules : key => rule if rule.direction == "outbound"
  }

  description                  = each.value.description
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
  security_group_id            = var.security_group_id

  tags = {
    Name = "${var.tag_prefix}${each.key}"
  }
}
