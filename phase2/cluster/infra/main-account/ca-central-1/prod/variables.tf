variable "ssh_public_key_path" {
  description = "Path to the SSH public key file for the EC2 key pair."
  type        = string
  nullable    = false
}

variable "ami_name_prefix" {
  description = "Name prefix filter for the custom kubeadm AMI built by Packer."
  type        = string
  default     = "vllm-phase2-kubeadm"
  nullable    = false
}
