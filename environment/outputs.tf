# deploy.yml reads these three by name. Renaming one breaks the SPA publish.

output "app_url" {
  description = "Public URL of the deployed application"
  value       = module.presentation_tier.app_url
}

output "spa_bucket_name" {
  description = "Bucket the SPA is synced into"
  value       = module.presentation_tier.bucket_name
}

output "cloudfront_distribution_id" {
  description = "Distribution invalidated after each SPA upload"
  value       = module.presentation_tier.distribution_id
}

# --- Diagnostics -----------------------------------------------------------

output "alb_dns_name" {
  description = "Load balancer hostname. Only reachable through CloudFront."
  value       = module.application_tier.alb_dns_name
}

output "ecs_cluster_name" {
  value = module.application_tier.cluster_name
}

output "ecs_service_name" {
  value = module.application_tier.service_name
}

output "log_group_name" {
  description = "Where backend container logs go"
  value       = module.application_tier.log_group_name
}

output "db_endpoint" {
  description = "Database hostname. Reachable only from the ECS tasks."
  value       = module.data_tier.endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager entry holding the master credentials"
  value       = module.data_tier.master_secret_arn
}

output "vpc_id" {
  value = module.network.vpc_id
}
