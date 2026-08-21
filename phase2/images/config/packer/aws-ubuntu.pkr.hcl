packer {
  required_plugins {
    amazon = {
      version = "~> 1.3.6"
      source  = "github.com/hashicorp/amazon"
    }

    ansible = {
      version = "~> 1.1.3"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "region" {
  type    = string
  default = "ca-central-1"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "vllm-phase2-kubeadm-{{timestamp}}"
  instance_type = "t4g.small"
  region        = var.region
  vpc_id        = var.vpc_id
  subnet_id     = var.subnet_id
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-resolute-26.04-arm64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
  tags = {
    Name = "vllm-phase2-kubeadm"
  }
}

build {
  sources = [
    "source.amazon-ebs.ubuntu",
  ]

  provisioner "ansible" {
    playbook_file = "../ansible/ami.yaml"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${path.root}/../ansible/ansible.cfg",
    ]
  }
}
