output "alb_dns_name" {
  description = "Load balancer hostname. Feeds the /api/* origin in the presentation tier."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone of the load balancer, for a Route53 alias record later."
  value       = aws_lb.main.zone_id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.app_service.name
}

output "task_security_group_id" {
  value = aws_security_group.tasks_sg.id
}

output "log_group_name" {
  description = "Where to look when a container misbehaves."
  value       = aws_cloudwatch_log_group.app_log_group.name
}
