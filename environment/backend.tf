terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Empty on purpose — the workflow injects values with -backend-config.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
