module "network" {
  source = "../modules/network"

  name               = var.project_name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
  tags               = var.tags
}
