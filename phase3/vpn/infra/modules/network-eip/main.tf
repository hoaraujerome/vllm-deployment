resource "aws_eip" "this" {
  domain = "vpc"

  tags = {
    Name = "${var.tag_prefix}eip"
  }
}

resource "aws_eip_association" "this" {
  instance_id   = var.instance_id
  allocation_id = aws_eip.this.id
}
