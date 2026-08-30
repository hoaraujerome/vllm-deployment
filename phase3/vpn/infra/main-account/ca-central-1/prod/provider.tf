provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "vllm-deployment"
      Phase       = "phase3"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
