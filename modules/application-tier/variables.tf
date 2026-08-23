variable "name" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the load balancer. Needs at least two AZs."
  type        = list(string)
}

variable "app_subnet_ids" {
  description = "Private app subnets for the Fargate tasks. Must have a NAT route, or image pulls fail."
  type        = list(string)
}

# --- Backend container -------------------------------------------------

variable "backend_image" {
  description = "Full ECR image URI including tag, e.g. 123456789012.dkr.ecr.eu-west-1.amazonaws.com/api:v1"
  type        = string
}

variable "backend_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080

  validation {
    condition     = var.backend_port > 0 && var.backend_port < 65536
    error_message = "backend_port must be between 1 and 65535."
  }
}

variable "health_path" {
  description = "HTTP path the load balancer polls. Must return 200 without authentication."
  type        = string
  default     = "/health"

  validation {
    condition     = startswith(var.health_path, "/")
    error_message = "health_path must start with a forward slash."
  }
}

variable "cpu_architecture" {
  description = <<-EOT
    Must match the architecture your image was built for. Images built on an
    Apple Silicon Mac without --platform are ARM64; the task will fail with
    "exec format error" if this does not match.
  EOT
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

# --- Task sizing -------------------------------------------------------

variable "cpu" {
  description = "Task CPU units. Fargate accepts 256, 512, 1024, 2048, 4096."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be one of 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = <<-EOT
    Task memory in MiB. Fargate only allows certain pairings with cpu:
      256  -> 512, 1024, 2048
      512  -> 1024..4096
      1024 -> 2048..8192
      2048 -> 4096..16384
      4096 -> 8192..30720
    An invalid pairing passes plan and fails at apply.
  EOT
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of tasks to keep running"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 1
    error_message = "desired_count must be at least 1."
  }
}

# --- Database wiring ---------------------------------------------------

variable "db_secret_arn" {
  description = "ARN of the RDS-managed master secret. Read by the execution role."
  type        = string
}

variable "db_security_group_id" {
  description = "Database security group. This module attaches the ingress rule allowing tasks in."
  type        = string
}

variable "db_endpoint" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

# --- Observability -----------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention. 0 keeps logs forever."
  type        = number
  default     = 14

  validation {
    condition = contains(
      [0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "log_retention_days must be a value CloudWatch accepts (0, 1, 3, 5, 7, 14, 30, 60, 90, ...)."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
