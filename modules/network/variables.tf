variable "name" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Split into /20s across three tiers."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread across"
  type        = number
  default     = 2

  # RDS needs two AZs; three tiers out of 16 /20 blocks caps it at five.
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 5
    error_message = "az_count must be between 2 and 5."
  }
}

variable "enable_nat_gateway" {
  description = "Outbound internet for private subnets. Required for ECR pulls."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "One NAT for all AZs instead of one each. ~$32/month cheaper, but that AZ becomes a single point of failure."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
