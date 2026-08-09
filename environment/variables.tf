# environments/variables.tf

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "myapp"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread across (2-3 recommended)"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. Cheaper, less resilient."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
