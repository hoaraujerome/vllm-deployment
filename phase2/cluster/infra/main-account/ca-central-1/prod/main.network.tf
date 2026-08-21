locals {
  aws_region                    = "ca-central-1"
  k8s_cluster_subnet_name       = "k8s-cluster"
  nat_gateway_subnet_name       = "nat-gateway"
  vpc_ipv4_cidr_block           = "10.60.0.0/16"
  k8s_cluster_subnet_cidr_block = "10.60.1.0/24"
  nat_gateway_subnet_cidr_block = "10.60.2.0/24"
}

module "vpc" {
  source = "../../../../../modules/infra/network-vpc"

  tag_prefix          = local.tag_prefix
  vpc_ipv4_cidr_block = local.vpc_ipv4_cidr_block
  subnets = {
    (local.k8s_cluster_subnet_name) = {
      ipv4_cidr_block         = local.k8s_cluster_subnet_cidr_block
      map_public_ip_on_launch = false
    }
    (local.nat_gateway_subnet_name) = {
      ipv4_cidr_block         = local.nat_gateway_subnet_cidr_block
      map_public_ip_on_launch = false
    }
  }
}

module "internet_gateway" {
  source = "../../../../../modules/infra/network-internetgateway"

  tag_prefix = local.tag_prefix
  vpc_id     = module.vpc.vpc_id
}

module "internet_gateway_route_table" {
  source = "../../../../../modules/infra/network-routetable-all-traffic"

  tag_prefix   = local.tag_prefix
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.subnet_ids[local.nat_gateway_subnet_name]
  gateway_id   = module.internet_gateway.id
  gateway_type = "igw"
}

module "nat_gateway" {
  source = "../../../../../modules/infra/network-natgateway"

  tag_prefix = local.tag_prefix
  subnet_id  = module.vpc.subnet_ids[local.nat_gateway_subnet_name]

  depends_on = [module.internet_gateway]
}

module "nat_gateway_route_table" {
  source = "../../../../../modules/infra/network-routetable-all-traffic"

  tag_prefix   = local.tag_prefix
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.subnet_ids[local.k8s_cluster_subnet_name]
  gateway_id   = module.nat_gateway.id
  gateway_type = "nat"
}
