provider "aws" {
  region = local.aws_region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "vllm-deployment"
      Environment = "phase2-prod"
      Stack       = "k8s-cluster"
    }
  }
}
