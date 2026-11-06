# Guards the CatchupETL IAM boundary: the function must run under its own
# dedicated CatchupETLRole (not the shared DefaultRole), keep the module
# permissions boundary, and receive only the AWS-managed VPC-access policy —
# never the broad DefaultRolePolicy grants (elasticache, DatabaseSecret, logs).
mock_provider "aws" {
  source = "./tests/mocks/aws"
  # apply mode materializes concrete values; the provider validates many of
  # them as ARNs, so give every computed-ARN resource type a valid ARN. The two
  # roles the assertions compare get distinct ARNs/ids via override_resource.
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/bt-test-mock" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/bt-test-mock" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:function:bt-test-mock" }
  }
  mock_resource "aws_lambda_layer_version" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:layer:bt-test-mock:1" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/bt-test-mock" }
  }
}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name         = "bt-test-org"
  deployment_name             = "bt-test"
  vpc_id                      = "vpc-12345678"
  service_subnet_ids          = ["subnet-11111111", "subnet-22222222"]
  postgres_username           = "bt"
  postgres_password           = "bt-password"
  postgres_host               = "db.example.internal"
  use_redis_replication_group = false
  redis_host                  = "redis.example.internal"
  redis_port                  = "6379"
  whitelisted_origins         = ["https://example.com"]
  code_bundle_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
  api_security_group_id       = "sg-12345678"
  api_handler_role_arn        = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
  function_tools_secret_key   = "test-secret-key"
  permissions_boundary_arn    = "arn:aws:iam::123456789012:policy/bt-test-boundary"
  use_quarantine_vpc          = false
}

run "catchup_etl_uses_its_own_least_privilege_role" {
  command = apply
  module { source = "./modules/services" }

  # Distinct, known ARNs/ids for the two roles the assertions compare. The
  # function still reads its role from aws_iam_role.catchup_etl.arn, so
  # repointing it at DefaultRole would make the ownership assertions fail.
  override_resource {
    target = aws_iam_role.catchup_etl
    values = {
      arn = "arn:aws:iam::123456789012:role/bt-test-CatchupETLRole"
      id  = "bt-test-CatchupETLRole"
    }
  }
  override_resource {
    target = aws_iam_role.default_role
    values = {
      arn = "arn:aws:iam::123456789012:role/bt-test-DefaultRole"
      id  = "bt-test-DefaultRole"
    }
  }

  # Ownership: the function runs under CatchupETLRole, not the shared DefaultRole.
  assert {
    condition     = aws_lambda_function.catchup_etl.role == aws_iam_role.catchup_etl.arn
    error_message = "CatchupETL must run under its dedicated CatchupETLRole."
  }
  assert {
    condition     = aws_lambda_function.catchup_etl.role != aws_iam_role.default_role.arn
    error_message = "CatchupETL must not fall back to the shared DefaultRole."
  }
  assert {
    condition     = aws_iam_role.catchup_etl.name == "bt-test-CatchupETLRole"
    error_message = "Dedicated role must be named <deployment_name>-CatchupETLRole."
  }

  # Trust policy: assumable only by Lambda.
  assert {
    condition = (
      length(jsondecode(aws_iam_role.catchup_etl.assume_role_policy).Statement) == 1 &&
      jsondecode(aws_iam_role.catchup_etl.assume_role_policy).Statement[0].Principal.Service == "lambda.amazonaws.com"
    )
    error_message = "CatchupETLRole must be assumable only by lambda.amazonaws.com."
  }

  # Permissions boundary is preserved on the dedicated role.
  assert {
    condition     = aws_iam_role.catchup_etl.permissions_boundary == var.permissions_boundary_arn
    error_message = "CatchupETLRole must keep the module permissions boundary."
  }

  # Only the AWS-managed VPC-access policy is attached, and to this role.
  assert {
    condition     = aws_iam_role_policy_attachment.catchup_etl_vpc_access.policy_arn == "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    error_message = "CatchupETLRole must receive only AWSLambdaVPCAccessExecutionRole."
  }
  assert {
    condition     = aws_iam_role_policy_attachment.catchup_etl_vpc_access.role == aws_iam_role.catchup_etl.name
    error_message = "The VPC-access attachment must target CatchupETLRole."
  }

  # Isolation: the broad DefaultRolePolicy (elasticache / DatabaseSecret / logs)
  # stays on DefaultRole and is never granted to the dedicated role. The module
  # defines no inline aws_iam_role_policy for CatchupETLRole, so the attachment
  # above is its only policy.
  assert {
    condition     = aws_iam_role_policy.default_role_policy.role == aws_iam_role.default_role.id
    error_message = "DefaultRolePolicy must stay on DefaultRole."
  }
  assert {
    condition     = aws_iam_role_policy.default_role_policy.role != aws_iam_role.catchup_etl.id
    error_message = "The broad DefaultRolePolicy must not be attached to CatchupETLRole."
  }
}
