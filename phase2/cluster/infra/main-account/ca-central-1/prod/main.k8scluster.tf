locals {
  ec2_instance_connect_endpoint_name = "ec2-instance-connect-endpoint"
  k8s_node_name                      = "k8s-node"
  ssh_port                           = 22
  tcp_protocol                       = "tcp"
  anywhere_ipv4                      = "0.0.0.0/0"
  http_port                          = 80
  https_port                         = 443
}

module "ssh_public_key" {
  source = "../../../modules/compute-sshpublickey"

  tag_prefix      = local.tag_prefix
  public_key_path = var.ssh_public_key_path
}

module "security_groups" {
  source = "../../../modules/network-securitygroup"

  tag_prefix = local.tag_prefix
  vpc_id     = module.vpc.vpc_id
  names = [
    local.ec2_instance_connect_endpoint_name,
    local.k8s_node_name,
  ]
}

module "ec2_instance_connect_endpoint_security_group_rules" {
  source = "../../../modules/network-securitygrouprules"

  tag_prefix        = local.tag_prefix
  security_group_id = module.security_groups.security_group_ids[local.ec2_instance_connect_endpoint_name]
  rules = {
    ssh_k8s_node_egress = {
      description                  = "SSH to the Kubernetes node"
      direction                    = "outbound"
      from_port                    = local.ssh_port
      to_port                      = local.ssh_port
      ip_protocol                  = local.tcp_protocol
      referenced_security_group_id = module.security_groups.security_group_ids[local.k8s_node_name]
    }
  }
}

module "k8s_node_security_group_rules" {
  source = "../../../modules/network-securitygrouprules"

  tag_prefix        = local.tag_prefix
  security_group_id = module.security_groups.security_group_ids[local.k8s_node_name]
  rules = {
    ssh_from_eice_ingress = {
      description                  = "SSH from EC2 Instance Connect Endpoint"
      direction                    = "inbound"
      from_port                    = local.ssh_port
      to_port                      = local.ssh_port
      ip_protocol                  = local.tcp_protocol
      referenced_security_group_id = module.security_groups.security_group_ids[local.ec2_instance_connect_endpoint_name]
    }
    http_egress = {
      description = "HTTP for package pulls"
      direction   = "outbound"
      from_port   = local.http_port
      to_port     = local.http_port
      ip_protocol = local.tcp_protocol
      cidr_ipv4   = local.anywhere_ipv4
    }
    https_egress = {
      description = "HTTPS for package pulls"
      direction   = "outbound"
      from_port   = local.https_port
      to_port     = local.https_port
      ip_protocol = local.tcp_protocol
      cidr_ipv4   = local.anywhere_ipv4
    }
  }
}

module "ec2_instance_connect_endpoint" {
  source = "../../../modules/network-ec2-instance-connect-endpoint"

  tag_prefix = local.tag_prefix
  subnet_id  = module.vpc.subnet_ids[local.k8s_cluster_subnet_name]
  security_group_ids = [
    module.security_groups.security_group_ids[local.ec2_instance_connect_endpoint_name],
  ]
}

module "k8s_node" {
  source = "../../../modules/compute-ec2"

  ami_name_prefix    = var.ami_name_prefix
  subnet_id          = module.vpc.subnet_ids[local.k8s_cluster_subnet_name]
  security_group_ids = [module.security_groups.security_group_ids[local.k8s_node_name]]
  key_pair_name      = module.ssh_public_key.key_pair_name
  tags = {
    Name = "${local.tag_prefix}${local.k8s_node_name}"
    Role = local.k8s_node_name
  }
}
