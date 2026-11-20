# Guards the CatchupETL IAM boundary: the function must run under its own
# dedicated CatchupETLRole (not the shared DefaultRole), keep the module
# permissions boundary, and receive only the AWS-managed VPC-access policy,
# never the broad DefaultRolePolicy grants (elasticache, DatabaseSecret, logs).
# iam_consumers.tftest.hcl checks that the function runs as this role.
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
  mock_resource "aws_iam_instance_profile" {
    defaults = { arn = "arn:aws:iam::123456789012:instance-profile/bt-test-mock" }
  }
}

variables {
  deployment_name   = "bt-test"
  create_ai_gateway = false

  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/bt-test-boundary"

  created_resources = {
    kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    database_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
    database_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database-url"
    function_tools_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
    redis_url_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    brainstore_s3_bucket_arn          = "arn:aws:s3:::bt-test-brainstore"
    code_bundle_s3_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
    lambda_responses_s3_bucket_arn    = "arn:aws:s3:::bt-test-lambda-responses"
  }

  brainstore_deployment_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment"
  brainstore_asg_names                = ["bt-test-brainstore-reader-123"]
}

run "catchup_etl_uses_its_own_least_privilege_role" {
  command = apply
  module { source = "./modules/iam" }

  # Distinct, known ARNs/ids for the two roles the assertions compare.
  override_resource {
    target = aws_iam_role.catchup_etl[0]
    values = {
      arn = "arn:aws:iam::123456789012:role/bt-test-CatchupETLRole"
      id  = "bt-test-CatchupETLRole"
    }
  }
  override_resource {
    target = aws_iam_role.default[0]
    values = {
      arn = "arn:aws:iam::123456789012:role/bt-test-DefaultRole"
      id  = "bt-test-DefaultRole"
    }
  }

  assert {
    condition     = output.catchup_etl_role_arn == aws_iam_role.catchup_etl[0].arn && output.catchup_etl_role_arn != aws_iam_role.default[0].arn
    error_message = "CatchupETL must get its dedicated CatchupETLRole, not the shared DefaultRole."
  }
  assert {
    condition     = aws_iam_role.catchup_etl[0].name == "bt-test-CatchupETLRole"
    error_message = "Dedicated role must be named <deployment_name>-CatchupETLRole."
  }

  # Trust policy: assumable only by Lambda.
  assert {
    condition = (
      length(jsondecode(aws_iam_role.catchup_etl[0].assume_role_policy).Statement) == 1 &&
      jsondecode(aws_iam_role.catchup_etl[0].assume_role_policy).Statement[0].Principal.Service == "lambda.amazonaws.com"
    )
    error_message = "CatchupETLRole must be assumable only by lambda.amazonaws.com."
  }

  # Permissions boundary is preserved on the dedicated role.
  assert {
    condition     = aws_iam_role.catchup_etl[0].permissions_boundary == var.permissions_boundary_arn
    error_message = "CatchupETLRole must keep the module permissions boundary."
  }

  # Only the AWS-managed VPC-access policy is attached, and to this role.
  assert {
    condition     = aws_iam_role_policy_attachment.catchup_etl_vpc_access[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    error_message = "CatchupETLRole must receive only AWSLambdaVPCAccessExecutionRole."
  }
  assert {
    condition     = aws_iam_role_policy_attachment.catchup_etl_vpc_access[0].role == aws_iam_role.catchup_etl[0].name
    error_message = "The VPC-access attachment must target CatchupETLRole."
  }

  # Isolation: the broad DefaultRolePolicy (elasticache / DatabaseSecret / logs)
  # stays on DefaultRole and is never granted to the dedicated role. The module
  # defines no inline aws_iam_role_policy for CatchupETLRole, so the attachment
  # above is its only policy.
  assert {
    condition     = aws_iam_role_policy.default[0].role == aws_iam_role.default[0].id
    error_message = "DefaultRolePolicy must stay on DefaultRole."
  }
  assert {
    condition     = aws_iam_role_policy.default[0].role != aws_iam_role.catchup_etl[0].id
    error_message = "The broad DefaultRolePolicy must not be attached to CatchupETLRole."
  }
}
