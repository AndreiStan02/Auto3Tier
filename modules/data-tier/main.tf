resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-db-subnet-group" })
}

# Deliberately has no ingress rules. The application tier attaches its own
# rule to this group, which is what keeps the dependency between the two
# modules one-directional — data-tier cannot reference the task security
# group, because application-tier needs this module's secret ARN.
resource "aws_security_group" "db_sg" {
  name        = "${var.name}-db-sg"
  description = "Security group for RDS database"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-db-sg" })
}

resource "aws_db_instance" "db_instance" {
  identifier     = "${var.name}-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username

  # RDS generates the master password and owns the Secrets Manager entry,
  # so it never appears in Terraform state. Deleting the instance deletes
  # the secret with it, with no recovery window to block a redeploy.
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  # These three exist so the destroy workflow can run unattended. They are
  # also data-loss footguns: no final snapshot, no protection, no backups.
  # See the warning in the README.
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0

  # Changes take effect now rather than in the weekly maintenance window,
  # so an apply that reports success has actually happened.
  apply_immediately = true

  tags = merge(var.tags, { Name = "${var.name}-db" })
}
