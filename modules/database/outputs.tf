output "postgres_database_address" {
  value       = aws_db_instance.main.address
  description = "The domain name of the main Postgres database"
}

output "postgres_database_port" {
  value       = aws_db_instance.main.port
  description = "The port of the main Postgres database"
}

output "postgres_database_arn" {
  value       = aws_db_instance.main.arn
  description = "The ARN of the main Postgres database"
}