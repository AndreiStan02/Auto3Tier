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

  # Two is a hard floor: RDS refuses to create a subnet group with fewer.
  # Five is the ceiling because three tiers are carved out of the 16 /20
  # blocks that cidrsubnet(vpc_cidr, 4, n) produces.
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 5
    error_message = "az_count must be between 2 and 5."
  }
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Give the private app subnets outbound internet access.
    Required for ECR image pulls and CloudWatch — with this off, ECS tasks
    cannot start unless you add interface VPC endpoints yourself.
  EOT
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = <<-EOT
    Share one NAT gateway across all AZs instead of one per AZ.
    Saves roughly $32/month per AZ avoided, at the cost of resilience: if
    that AZ fails, every private subnet loses egress. No effect when
    enable_nat_gateway is false.
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
