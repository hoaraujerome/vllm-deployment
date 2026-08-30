# Phase 2 cluster resources discovery via AWS data sources

# Phase 2 VPC
data "aws_vpc" "phase2" {
  filter {
    name   = "tag:Name"
    values = ["vllm-phase2-cluster-vpc"]
  }
}

# Phase 2 nat-gateway subnet (public-facing subnet for WireGuard)
data "aws_subnet" "nat_gateway" {
  filter {
    name   = "tag:Name"
    values = ["vllm-phase2-cluster-nat-gateway"]
  }

  vpc_id = data.aws_vpc.phase2.id
}

# Phase 2 K8s node security group
data "aws_security_group" "k8s_node" {
  filter {
    name   = "tag:Name"
    values = ["vllm-phase2-cluster-k8s-node-security-group"]
  }

  vpc_id = data.aws_vpc.phase2.id
}

# Phase 2 K8s node instance
data "aws_instance" "k8s_node" {
  filter {
    name   = "tag:Name"
    values = ["vllm-phase2-cluster-k8s-node"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Current public IP for dynamic home IP
data "http" "current_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  current_home_ip = "${trimspace(data.http.current_ip.response_body)}/32"
}
