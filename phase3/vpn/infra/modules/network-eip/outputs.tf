output "id" {
  description = "EIP allocation ID."
  value       = aws_eip.this.id
}

output "public_ip" {
  description = "The Elastic IP address."
  value       = aws_eip.this.public_ip
}

output "association_id" {
  description = "EIP association ID."
  value       = aws_eip_association.this.id
}
