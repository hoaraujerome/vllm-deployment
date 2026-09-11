# Ubuntu 26.04 LTS ARM64 AMI lookup
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip_address
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_pair_name
  user_data                   = var.user_data

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens            = "required"
    instance_metadata_tags = "enabled"
  }

  tags = var.tags

  # Terraform AWS provider drift bug: https://github.com/hashicorp/terraform-provider-aws/issues/47100
  # aws_eip_association refresh can report associate_public_ip_address=true even
  # when launch used false; the attribute is ForceNew and causes perpetual replace.
  lifecycle {
    ignore_changes = [associate_public_ip_address]
  }
}
