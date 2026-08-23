resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-db-subnet-group" })
}

# No ingress rules here. The application tier attaches its own, which is what
# keeps the two modules from forming a dependency cycle.
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

  # Password generated and held by RDS, so it never enters state. Dropped with
  # the instance, with no recovery window to block a redeploy.
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  # Required for unattended destroy. No snapshot, no backups — see README.
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0

  # Apply now rather than in the maintenance window, so a green apply is real.
  apply_immediately = true

  tags = merge(var.tags, { Name = "${var.name}-db" })
}
