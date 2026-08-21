# Cluster live root (placeholder)

Terraform for the long-lived kubeadm cluster (VPC, NAT, EICE, EC2, security groups) will live here.

When scaffolded, configure AWS provider `default_tags` separately from the AMI builder live root, for example:

```hcl
provider "aws" {
  region = local.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "vllm-deployment"
      Environment = "phase2-dev"
      Stack       = "k8s-cluster"
    }
  }
}
```

Shared modules under `phase2/modules/infra/` do not define organizational tags — only resource `Name` values.
