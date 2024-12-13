resource "aws_db_instance" "main" {
  identifier     = "${var.deployment_name}-main"
  engine         = "postgres"
  engine_version = var.postgres_version

  instance_class    = var.postgres_instance_type
  allocated_storage = var.postgres_storage_size
  storage_type      = var.postgres_storage_type

  db_name  = "postgres"
  username = jsondecode(aws_secretsmanager_secret_version.database_secret.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.database_secret.secret_string)["password"]

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = var.database_security_group_ids

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.db_monitoring.arn

  storage_encrypted = true

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.deployment_name}-main-final-snapshot"
}

resource "aws_db_parameter_group" "main" {
  name        = "${var.deployment_name}-main"
  family      = "postgres${split(".", var.postgres_version)[0]}"
  description = "DB parameter group for the Braintrust main database"

  parameter {
    name  = "random_page_cost"
    value = "1"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pg_hint_plan,pg_cron"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "statement_timeout"
    value = "3600000"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.deployment_name}-main"
  description = "Subnet group for the Braintrust main database"
  subnet_ids  = var.database_subnet_ids
}

resource "aws_iam_role" "db_monitoring" {
  name = "${var.deployment_name}-db-monitoring"

  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_monitoring" {
  role       = aws_iam_role.db_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_secretsmanager_random_password" "database_secret" {
  password_length     = 16
  exclude_characters  = "\"'@/\\"
  exclude_punctuation = true
}

resource "aws_secretsmanager_secret_version" "database_secret" {
  secret_id = aws_secretsmanager_secret.database_secret.id
  secret_string = jsonencode({
    username = "postgres"
    password = data.aws_secretsmanager_random_password.database_secret.random_password
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "database_secret" {
  name        = "${var.deployment_name}/DatabaseSecret"
  description = "Username/password for the main Braintrust RDS database"
}
