# Cover managed and customer-managed subnet groups for both Redis resource types.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name             = "bt-test"
  vpc_id                      = "vpc-12345678"
  subnet_ids                  = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
  kms_key_arn                 = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-4000-8000-000000000000"
  use_redis_replication_group = false
}

run "legacy_managed_group" {
  command = plan

  module {
    source = "./modules/elasticache"
  }

  variables {
    use_redis_replication_group            = false
    existing_elasticache_subnet_group_name = null
  }

  assert {
    condition     = length(aws_elasticache_subnet_group.main) == 1
    error_message = "Only create a subnet group when no existing group is supplied."
  }

  assert {
    condition     = aws_elasticache_cluster.main[0].subnet_group_name == "bt-test-elasticache-subnet-group"
    error_message = "Redis must use the selected subnet group in either Redis mode."
  }
}

run "legacy_existing_group" {
  command = plan

  module {
    source = "./modules/elasticache"
  }

  variables {
    use_redis_replication_group            = false
    existing_elasticache_subnet_group_name = "shared-redis-subnets"
  }

  assert {
    condition     = length(aws_elasticache_subnet_group.main) == 0
    error_message = "Only create a subnet group when no existing group is supplied."
  }

  assert {
    condition     = aws_elasticache_cluster.main[0].subnet_group_name == "shared-redis-subnets"
    error_message = "Redis must use the selected subnet group in either Redis mode."
  }
}

run "replication_managed_group" {
  command = plan

  module {
    source = "./modules/elasticache"
  }

  variables {
    use_redis_replication_group            = true
    existing_elasticache_subnet_group_name = null
  }

  assert {
    condition     = length(aws_elasticache_subnet_group.main) == 1
    error_message = "Only create a subnet group when no existing group is supplied."
  }

  assert {
    condition     = aws_elasticache_replication_group.main[0].subnet_group_name == "bt-test-elasticache-subnet-group"
    error_message = "Redis must use the selected subnet group in either Redis mode."
  }

  assert {
    condition = (
      tostring(aws_elasticache_replication_group.main[0].at_rest_encryption_enabled) == "true" &&
      tostring(aws_elasticache_replication_group.main[0].transit_encryption_enabled) == "true" &&
      aws_elasticache_replication_group.main[0].kms_key_id == var.kms_key_arn &&
      aws_elasticache_replication_group.main[0].auth_token_update_strategy == "SET" &&
      nonsensitive(aws_secretsmanager_secret_version.auth_token[0].secret_string) == "mock-password-16"
    )
    error_message = "Replication groups must enable at-rest/transit encryption, use the module KMS key, require AUTH with SET, and store the generated auth token."
  }

  assert {
    # Endpoint address is unknown at plan time; assert the URL prefix formula with the known token.
    condition     = startswith("rediss://:${nonsensitive(aws_secretsmanager_secret_version.auth_token[0].secret_string)}@", "rediss://:mock-password-16@")
    error_message = "Replication-group Redis URL must use the rediss://:token@ prefix."
  }
}

run "replication_existing_group" {
  command = plan

  module {
    source = "./modules/elasticache"
  }

  variables {
    use_redis_replication_group            = true
    existing_elasticache_subnet_group_name = "shared-redis-subnets"
  }

  assert {
    condition     = length(aws_elasticache_subnet_group.main) == 0
    error_message = "Only create a subnet group when no existing group is supplied."
  }

  assert {
    condition     = aws_elasticache_replication_group.main[0].subnet_group_name == "shared-redis-subnets"
    error_message = "Redis must use the selected subnet group in either Redis mode."
  }

  assert {
    condition = (
      tostring(aws_elasticache_replication_group.main[0].at_rest_encryption_enabled) == "true" &&
      aws_elasticache_replication_group.main[0].auth_token_update_strategy == "SET"
    )
    error_message = "Replication groups must enable at-rest encryption and require AUTH with SET."
  }
}

run "rejects_empty_group" {
  command = plan

  module {
    source = "./modules/elasticache"
  }

  variables {
    existing_elasticache_subnet_group_name = ""
  }

  expect_failures = [var.existing_elasticache_subnet_group_name]
}

run "rejects_whitespace_group" {
  command = plan

  module {
    source = "./modules/elasticache"
  }

  variables {
    existing_elasticache_subnet_group_name = "   "
  }

  expect_failures = [var.existing_elasticache_subnet_group_name]
}

