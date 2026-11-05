variable "service_additional_policy_arns" {
  type    = list(string)
  default = []
}

module "services_common" {
  source = "../../../modules/services-common"

  deployment_name                   = "bt-test"
  vpc_id                            = "vpc-12345678"
  kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/test"
  brainstore_s3_bucket_arn          = "arn:aws:s3:::bt-test-brainstore"
  database_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  code_bundle_s3_bucket_arn         = "arn:aws:s3:::bt-test-code"
  lambda_responses_s3_bucket_arn    = "arn:aws:s3:::bt-test-responses"
  enable_quarantine_vpc             = false
  service_additional_policy_arns    = var.service_additional_policy_arns
}

module "brainstore" {
  source = "../../../modules/brainstore-ec2"

  deployment_name                       = "bt-test"
  license_key_secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  license_key_secret_version            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-test-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-test-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-test-code"
  brainstore_iam_role_name              = module.services_common.brainstore_iam_role_name
  brainstore_instance_security_group_id = module.services_common.brainstore_instance_security_group_id
  ai_proxy_url_ssm_parameter            = "/bt-test/ai-proxy-url"
  writer_instance_count                 = 1
  fast_reader_instance_count            = 1
  automation_writer_instance_count      = 1
}

output "deployment_fleets" {
  value = module.brainstore.deployment_fleets
}
