output "wireguard_instance_id" {
  description = "EC2 instance ID of the WireGuard server."
  value       = module.wireguard.instance_id
}

output "wireguard_public_ip" {
  description = "Elastic IP (public) of the WireGuard server."
  value       = module.wireguard_eip.public_ip
}

output "wireguard_private_ip" {
  description = "Private IP of the WireGuard server."
  value       = module.wireguard.private_ip
}

output "wireguard_eip" {
  description = "WireGuard server Elastic IP address"
  value       = module.wireguard_eip.public_ip
}

output "wireguard_security_group_id" {
  description = "Security group ID of the WireGuard server."
  value       = module.wireguard_sg.security_group_ids[local.wireguard_node_name]
}

output "k8s_node_private_ip" {
  description = "K8s node private IP (from Phase 2) for kubeconfig."
  value       = data.aws_instance.k8s_node.private_ip
}

output "current_home_ip" {
  description = "Current home IP (dynamically fetched) used for WireGuard/SSH ingress."
  value       = local.current_home_ip
}

output "ssh_private_key_path" {
  description = "SSH private key path for connecting to WireGuard server."
  value       = var.ssh_private_key_path
}
