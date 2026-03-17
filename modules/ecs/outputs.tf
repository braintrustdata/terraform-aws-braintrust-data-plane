output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.dataplane.arn
}

output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.dataplane.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.dataplane.name
}
