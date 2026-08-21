resource "aws_security_group" "this" {
  for_each = var.names

  name        = "${var.tag_prefix}${each.value}"
  description = "${var.tag_prefix}${each.value} security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.tag_prefix}${each.value}-security-group"
  }
}
