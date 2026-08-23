module "network" {
  source = "../modules/network"

  name               = var.project_name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  tags               = var.tags
}

module "data_tier" {
  source = "../modules/data-tier"

  name       = var.project_name
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.data_subnet_ids

  db_name           = var.db_name
  db_username       = var.db_username
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  multi_az          = var.db_multi_az

  tags = var.tags
}

# Owns the ALB as well as ECS, so the whole request path lives in one module.
# Attaches its own ingress rule to the database security group, which is what
# keeps the dependency between this and data_tier one-directional.
module "application_tier" {
  source = "../modules/application-tier"

  name              = var.project_name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  app_subnet_ids    = module.network.app_subnet_ids

  backend_image    = var.backend_image
  backend_port     = var.backend_port
  health_path      = var.health_path
  cpu_architecture = var.cpu_architecture

  cpu           = var.cpu
  memory        = var.memory
  desired_count = var.desired_count

  db_secret_arn        = module.data_tier.master_secret_arn
  db_security_group_id = module.data_tier.security_group_id
  db_endpoint          = module.data_tier.endpoint
  db_port              = module.data_tier.port
  db_name              = module.data_tier.db_name

  tags = var.tags
}

# Serves the SPA from S3 and proxies /api/* to the load balancer, so the
# browser only ever sees one origin.
module "presentation_tier" {
  source = "../modules/presentation-tier"

  name         = var.project_name
  alb_dns_name = module.application_tier.alb_dns_name
  price_class  = var.price_class

  tags = var.tags
}
