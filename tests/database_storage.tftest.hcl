# The fixture reuses the database source without exporting credentials as root outputs.
# Mocked applies make provider-computed throughput known without contacting AWS.
mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/database-monitoring"
    }
  }

  mock_resource "aws_db_instance" {
    # A computed sentinel distinguishes an omitted argument from configured gp3 throughput.
    defaults = {
      storage_throughput = 0
    }
  }
}

mock_provider "random" {}

variables {
  deployment_name             = "bt-test"
  vpc_id                      = "vpc-0123456789abcdef0"
  database_subnet_ids         = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
  postgres_storage_iops       = 12000
  postgres_storage_throughput = 500
}

run "preserves_default_gp3_storage_performance" {
  command = apply

  module {
    source = "./tests/fixtures/database-storage"
  }

  assert {
    condition = (
      aws_db_instance.main.storage_type == "gp3" &&
      aws_db_instance.main.storage_throughput == 500 &&
      aws_db_instance.main.iops == 12000
    )
    error_message = "Default gp3 storage must retain its configured throughput and IOPS."
  }
}

run "preserves_custom_gp3_storage_performance" {
  command = apply

  module {
    source = "./tests/fixtures/database-storage"
  }

  variables {
    postgres_storage_iops       = 40000
    postgres_storage_throughput = 1000
  }

  assert {
    condition = (
      aws_db_instance.main.storage_throughput == 1000 &&
      aws_db_instance.main.iops == 40000
    )
    error_message = "Custom gp3 throughput and IOPS must be passed to RDS."
  }
}

run "omits_gp3_throughput_for_io2" {
  command = apply

  # Reset only the simulated DB so a prior gp3 value cannot remain in computed state.
  plan_options {
    replace = [aws_db_instance.main]
  }

  module {
    source = "./tests/fixtures/database-storage"
  }

  variables {
    postgres_instance_type = "db.r6in.16xlarge"
    postgres_storage_type  = "io2"
    postgres_storage_iops  = 160000
  }

  assert {
    condition = (
      aws_db_instance.main.storage_type == "io2" &&
      aws_db_instance.main.storage_throughput == 0 &&
      aws_db_instance.main.iops == 160000
    )
    error_message = "io2 must omit gp3-only throughput while retaining provisioned IOPS."
  }
}

run "omits_gp3_throughput_for_io1" {
  command = apply

  # Reset only the simulated DB so a prior gp3 value cannot remain in computed state.
  plan_options {
    replace = [aws_db_instance.main]
  }

  module {
    source = "./tests/fixtures/database-storage"
  }

  variables {
    postgres_storage_type = "io1"
    postgres_storage_iops = 40000
  }

  assert {
    condition = (
      aws_db_instance.main.storage_type == "io1" &&
      aws_db_instance.main.storage_throughput == 0 &&
      aws_db_instance.main.iops == 40000
    )
    error_message = "io1 must omit gp3-only throughput while retaining provisioned IOPS."
  }
}
