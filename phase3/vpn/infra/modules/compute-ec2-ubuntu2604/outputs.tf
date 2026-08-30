output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of the instance (if any)."
  value       = aws_instance.this.public_ip
}

output "arn" {
  description = "ARN of the instance."
  value       = aws_instance.this.arn
}

output "ami_id" {
  description = "AMI ID used for the instance."
  value       = data.aws_ami.ubuntu.id
}
