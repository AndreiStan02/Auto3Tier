terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Intentionally empty — values are injected at init time by the
  # GitHub Actions workflow via -backend-config flags, so nobody
  # has to edit this file or invent a bucket name.
  # backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
