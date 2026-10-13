# Cover managed and customer-managed subnet groups for both Redis resource types.
mock_provider "aws" {}

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

