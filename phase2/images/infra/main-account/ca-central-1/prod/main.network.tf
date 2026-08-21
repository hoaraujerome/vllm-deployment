locals {
  aws_region                    = "ca-central-1"
  packer_subnet_name            = "packer"
  vpc_ipv4_cidr_block           = "10.50.0.0/16"
  packer_subnet_ipv4_cidr_block = "10.50.1.0/24"
}

module "vpc" {
  source = "../../../../../modules/infra/network-vpc"

  vpc_ipv4_cidr_block = local.vpc_ipv4_cidr_block
  subnets = {
    (local.packer_subnet_name) = {
      ipv4_cidr_block         = local.packer_subnet_ipv4_cidr_block
      map_public_ip_on_launch = true
    }
  }
}

module "internet_gateway" {
  source = "../../../../../modules/infra/network-internetgateway"

  vpc_id = module.vpc.vpc_id
}

module "internet_gateway_route_table" {
  source = "../../../../../modules/infra/network-routetable-all-traffic"

  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.subnet_ids[local.packer_subnet_name]
  gateway_id   = module.internet_gateway.id
  gateway_type = "igw"
}

output "packer_vpc_id" {
  value = module.vpc.vpc_id
}

output "packer_subnet_id" {
  value = module.vpc.subnet_ids[local.packer_subnet_name]
}
