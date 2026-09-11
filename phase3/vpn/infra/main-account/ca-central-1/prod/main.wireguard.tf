# WireGuard VPN infrastructure

module "ssh_key" {
  source = "../../../modules/compute-sshpublickey"

  tag_prefix      = local.tag_prefix
  public_key_path = var.ssh_public_key_path
}

module "wireguard_sg" {
  source = "../../../modules/network-securitygroup"

  tag_prefix = local.tag_prefix
  vpc_id     = data.aws_vpc.phase2.id
  names = [
    local.wireguard_node_name,
  ]
}

module "wireguard_sg_rules" {
  source = "../../../modules/network-securitygrouprules"

  tag_prefix        = local.tag_prefix
  security_group_id = module.wireguard_sg.security_group_ids[local.wireguard_node_name]
  rules = {
    wireguard_udp_ingress = {
      description = "WireGuard UDP from home IP (dynamic)"
      direction   = "inbound"
      from_port   = local.wireguard_port
      to_port     = local.wireguard_port
      ip_protocol = local.udp_protocol
      cidr_ipv4   = local.current_home_ip
    }
    ssh_ingress = {
      description = "SSH from home IP (break-glass, dynamic)"
      direction   = "inbound"
      from_port   = local.ssh_port
      to_port     = local.ssh_port
      ip_protocol = local.tcp_protocol
      cidr_ipv4   = local.current_home_ip
    }
    vpc_egress = {
      description = "Allow outbound to VPC CIDR"
      direction   = "outbound"
      ip_protocol = "-1"
      cidr_ipv4   = data.aws_vpc.phase2.cidr_block
    }
    # Trivy AWS-0104 flags 0.0.0.0/0 egress; we accept that here because Ubuntu apt
    # mirrors resolve to many public IPs and cannot be pinned to a small CIDR list.
    # Scope is limited to TCP 80/443 only (not all protocols/ports like a blanket allow-all).
    http_egress = {
      description = "HTTP for package updates"
      direction   = "outbound"
      from_port   = local.http_port
      to_port     = local.http_port
      ip_protocol = local.tcp_protocol
      cidr_ipv4   = local.anywhere_ipv4
    }
    https_egress = {
      description = "HTTPS for package updates"
      direction   = "outbound"
      from_port   = local.https_port
      to_port     = local.https_port
      ip_protocol = local.tcp_protocol
      cidr_ipv4   = local.anywhere_ipv4
    }
  }
}

# K8s node security group ingress rule (TCP 6443 from WireGuard SG)
module "k8s_api_from_wireguard_rule" {
  source = "../../../modules/network-securitygrouprules"

  tag_prefix        = local.tag_prefix
  security_group_id = data.aws_security_group.k8s_node.id
  rules = {
    k8s_api_ingress = {
      description                  = "K8s API from WireGuard VPN"
      direction                    = "inbound"
      from_port                    = local.k8s_api_port
      to_port                      = local.k8s_api_port
      ip_protocol                  = local.tcp_protocol
      referenced_security_group_id = module.wireguard_sg.security_group_ids[local.wireguard_node_name]
    }
  }
}

# K8s node security group ingress rule (TCP 22 from WireGuard SG — kubeconfig fetch hop)
module "k8s_ssh_from_wireguard_rule" {
  source = "../../../modules/network-securitygrouprules"

  tag_prefix        = local.tag_prefix
  security_group_id = data.aws_security_group.k8s_node.id
  rules = {
    ssh_from_wireguard_ingress = {
      description                  = "SSH from WireGuard EC2 (kubeconfig fetch hop)"
      direction                    = "inbound"
      from_port                    = local.ssh_port
      to_port                      = local.ssh_port
      ip_protocol                  = local.tcp_protocol
      referenced_security_group_id = module.wireguard_sg.security_group_ids[local.wireguard_node_name]
    }
  }
}

module "wireguard" {
  source = "../../../modules/compute-ec2-ubuntu2604"

  instance_type               = var.wireguard_instance_type
  subnet_id                   = data.aws_subnet.nat_gateway.id
  associate_public_ip_address = false
  security_group_ids          = [module.wireguard_sg.security_group_ids[local.wireguard_node_name]]
  key_pair_name               = module.ssh_key.key_pair_name

  user_data = file("${path.module}/../../../../../configuration/wireguard-server-cloud-init.yaml")

  tags = {
    Name = "${local.tag_prefix}${local.wireguard_node_name}"
    Role = local.wireguard_node_name
  }
}

module "wireguard_eip" {
  source = "../../../modules/network-eip"

  tag_prefix  = local.tag_prefix
  instance_id = module.wireguard.instance_id
}
