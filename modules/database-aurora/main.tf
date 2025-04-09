locals {
  postgres_username = jsondecode(aws_secretsmanager_secret_version.database_secret.secret_string)["username"]
  postgres_password = jsondecode(aws_secretsmanager_secret_version.database_secret.secret_string)["password"]
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.deployment_name}-main"
  engine             = "aurora-postgresql"
  engine_version     = var.postgres_version
  engine_mode        = "" # Don't use serverless mode
  database_name      = "postgres"
  master_username    = local.postgres_username
  master_password    = local.postgres_password

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.database_security_group_ids

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn
  storage_type      = "aurora-iopt1"

  backtrack_window    = var.backtrack_window
  deletion_protection = var.deletion_protection

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.deployment_name}-main-final-snapshot-${random_id.snapshot_suffix.hex}"
  copy_tags_to_snapshot     = true

  database_insights_mode                = "standard"
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = ["instance", "postgresql"]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      cluster_identifier,
      kms_key_id,
      storage_encrypted,
      db_subnet_group_name
    ]
  }
}

resource "aws_rds_cluster_instance" "main" {
  identifier         = "${var.deployment_name}-main-0"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.postgres_instance_type
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  db_parameter_group_name = aws_db_parameter_group.main.name

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.db_monitoring.arn

  tags = local.common_tags
}

resource "random_id" "snapshot_suffix" {
  byte_length = 4
}

resource "aws_rds_cluster_parameter_group" "main" {
  family      = "aurora-postgresql${split(".", var.postgres_version)[0]}"
  name_prefix = "${var.deployment_name}-main"
  description = "DB cluster parameter group for the Braintrust main database"

  parameter {
    name  = "statement_timeout"
    value = "3600000"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_db_parameter_group" "main" {
  family      = "aurora-postgresql${split(".", var.postgres_version)[0]}"
  name_prefix = "${var.deployment_name}-main"
  description = "DB parameter group for the Braintrust main database"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pg_hint_plan,pg_cron"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "auto_explain.hashes"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "auto_explain.log_analyze"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "auto_explain.log_buffers"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "auto_explain.log_format"
    value        = "json"
    apply_method = "immediate"
  }

  parameter {
    name         = "auto_explain.log_min_duration"
    value        = "10000"
    apply_method = "immediate"
  }

  parameter {
    name         = "auto_explain.log_nested_statements"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "auto_explain.log_timing"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "auto_explain.log_triggers"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "auto_explain.log_verbose"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "10000"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_parameter_max_length"
    value        = "128"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_temp_files"
    value        = "100"
    apply_method = "immediate"
  }

  parameter {
    name         = "work_mem"
    value        = "262144"
    apply_method = "immediate"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_db_subnet_group" "main" {
  name_prefix = "${var.deployment_name}-main"
  description = "Subnet group for the Braintrust main database"
  subnet_ids  = var.database_subnet_ids

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
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

  tags = local.common_tags
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
  name_prefix = "${var.deployment_name}/DatabaseSecret-"
  description = "Username/password for the main Braintrust Aurora database"
  kms_key_id  = var.kms_key_arn

  tags = local.common_tags
}
