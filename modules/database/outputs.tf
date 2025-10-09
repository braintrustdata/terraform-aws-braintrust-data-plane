output "postgres_database_address" {
  value       = aws_db_instance.main.address
  description = "The domain name of the main Postgres database"
}

output "postgres_database_port" {
  value       = aws_db_instance.main.port
  description = "The port of the main Postgres database"
}

output "postgres_database_identifier" {
  value       = aws_db_instance.main.identifier
  description = "The identifier of the main Postgres database"
}

output "postgres_database_arn" {
  value       = aws_db_instance.main.arn
  description = "The ARN of the main Postgres database"
}

output "postgres_database_username" {
  value       = local.postgres_username
  description = "The username for the main Postgres database"
}

output "postgres_database_password" {
  value       = local.postgres_password
  description = "The password for the main Postgres database"
}

output "postgres_database_secret_arn" {
  value       = aws_secretsmanager_secret.database_secret.arn
  description = "The ARN of the secret containing the main Postgres database credentials"
}

output "rds_security_group_id" {
  value       = aws_security_group.rds.id
  description = "The ID of the security group for the RDS instance"
}