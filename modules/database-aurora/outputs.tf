output "postgres_database_address" {
  value       = aws_rds_cluster.main.endpoint
  description = "The domain name of the main Aurora PostgreSQL cluster"
}

output "postgres_database_port" {
  value       = aws_rds_cluster.main.port
  description = "The port of the main Aurora PostgreSQL cluster"
}

output "postgres_database_arn" {
  value       = aws_rds_cluster.main.arn
  description = "The ARN of the main Aurora PostgreSQL cluster"
}

output "postgres_database_username" {
  value       = local.postgres_username
  description = "The username for the main Aurora PostgreSQL cluster"
}

output "postgres_database_password" {
  value       = local.postgres_password
  description = "The password for the main Aurora PostgreSQL cluster"
}

output "postgres_database_secret_arn" {
  value       = aws_secretsmanager_secret.database_secret.arn
  description = "The ARN of the secret containing the main Aurora PostgreSQL cluster credentials"
}

output "postgres_database_reader_endpoint" {
  value       = aws_rds_cluster.main.reader_endpoint
  description = "A read-only endpoint for the Aurora PostgreSQL cluster"
}

output "postgres_database_cluster_identifier" {
  value       = aws_rds_cluster.main.cluster_identifier
  description = "The cluster identifier of the Aurora PostgreSQL cluster"
}
