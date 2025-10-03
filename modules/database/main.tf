locals {
  postgres_username = jsondecode(aws_secretsmanager_secret_version.database_secret.secret_string)["username"]
  postgres_password = jsondecode(aws_secretsmanager_secret_version.database_secret.secret_string)["password"]
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.deployment_name}-main"
  engine         = "postgres"
  engine_version = var.postgres_version

  instance_class = var.postgres_instance_type

  storage_encrypted     = true
  allocated_storage     = var.postgres_storage_size
  max_allocated_storage = var.postgres_max_storage_size
  storage_type          = var.postgres_storage_type
  storage_throughput    = var.postgres_storage_throughput
  iops                  = var.postgres_storage_iops
  multi_az              = var.multi_az

  db_name  = "postgres"
  username = local.postgres_username
  password = local.postgres_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.db_monitoring.arn

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.deployment_name}-main-final-snapshot-${random_id.snapshot_suffix.hex}"
  copy_tags_to_snapshot     = true
  backup_retention_period   = 3
  backup_window             = "00:00-00:30"
  maintenance_window        = "Mon:08:00-Mon:11:00" # This is in UTC, so it is 12am-3am in PST

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  deletion_protection        = !var.DANGER_disable_deletion_protection

  kms_key_id = var.kms_key_arn

  tags = local.common_tags

  lifecycle {
    # These can't be changed without recreating the RDS instance
    ignore_changes = [
      identifier,
      kms_key_id,
      storage_encrypted,
      db_subnet_group_name
    ]
  }
}

resource "random_id" "snapshot_suffix" {
  byte_length = 4
}

resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.deployment_name}-main"
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

  assume_role_policy = jsonencode({ # nosemgrep
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
  description = "Username/password for the main Braintrust RDS database"
  kms_key_id  = var.kms_key_arn

  tags = local.common_tags
}

#------------------------------------------------------------------------------
# Security groups
#------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name   = "${var.deployment_name}-rds"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.deployment_name}-rds" }, local.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "rds_allow_ingress_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow TCP/5432 (PostgreSQL) inbound to RDS from ${each.key}."

  security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_egress_rule" "rds_allow_egress_all" {

  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic from RDS instances."
  security_group_id = aws_security_group.rds.id
}
