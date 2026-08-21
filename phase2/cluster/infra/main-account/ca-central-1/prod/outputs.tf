output "k8s_node_instance_id" {
  description = "EC2 instance ID of the Kubernetes node."
  value       = module.k8s_node.instance_id
}

output "ec2_instance_connect_endpoint_id" {
  description = "ID of the EC2 Instance Connect Endpoint for SSH access to the private node."
  value       = module.ec2_instance_connect_endpoint.id
}
