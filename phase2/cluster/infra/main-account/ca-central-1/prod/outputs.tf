output "k8s_node_instance_id" {
  description = "EC2 instance ID of the Kubernetes node."
  value       = module.k8s_node.instance_id
}

output "ec2_instance_connect_endpoint_id" {
  description = "ID of the EC2 Instance Connect Endpoint for SSH access to the private node."
  value       = module.ec2_instance_connect_endpoint.id
}

# Phase 3 interface outputs
output "vpc_id" {
  description = "VPC ID for Phase 3 WireGuard provisioning."
  value       = module.vpc.vpc_id
}

output "nat_gateway_subnet_id" {
  description = "NAT gateway subnet ID for Phase 3 WireGuard EC2 (public-facing subnet)."
  value       = module.vpc.subnet_ids[local.nat_gateway_subnet_name]
}

output "k8s_node_security_group_id" {
  description = "K8s node security group ID for Phase 3 ingress rule (TCP 6443 from WireGuard)."
  value       = module.security_groups.security_group_ids[local.k8s_node_name]
}

output "k8s_node_private_ip" {
  description = "K8s node private IP for Phase 3 kubeconfig server URL."
  value       = module.k8s_node.private_ip
}
