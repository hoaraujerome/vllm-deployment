#trivy:ignore:AVD-AWS-0178
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_ipv4_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.tag_prefix}vpc"
  }
}

#trivy:ignore:AVD-AWS-0164
resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.ipv4_cidr_block
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  tags = {
    Name = "${var.tag_prefix}${each.key}"
  }
}
