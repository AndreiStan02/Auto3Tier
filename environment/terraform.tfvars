project_name = "myapp"
aws_region   = "eu-west-1"

# --- Network -------------------------------------------------
vpc_cidr = "10.0.0.0/16"
az_count = 2

# single_nat_gateway = true saves roughly $30-35/month, but one AZ
# failure takes out internet access for all private subnets.
# Set false for production workloads.
single_nat_gateway = true

tags = {
  ManagedBy = "terraform"
}
