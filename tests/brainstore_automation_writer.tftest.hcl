# Verify automation-writer loop configuration is rendered into distinct
# launch-template user data for the regular and automation writer roles.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                       = "bt-automation-writer"
  license_key                           = "test-license"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-automation-writer-database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  use_redis_replication_group           = true
  redis_host                            = "redis.example.internal"
  redis_port                            = "6379"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-automation-writer-service-token"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-automation-writer-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-automation-writer-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-automation-writer-code-bundles"
  brainstore_iam_role_name              = "bt-automation-writer-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  ai_proxy_url_ssm_parameter            = "/bt-automation-writer/ai-proxy-url"
  automation_writer_instance_count      = 1
}

run "automation_writer_loop_config_is_rendered" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  assert {
    condition     = aws_launch_template.brainstore_writer[0].user_data != aws_launch_template.brainstore_automation_writer[0].user_data
    error_message = "regular and automation writers should render different writer-loop configuration"
  }
}
