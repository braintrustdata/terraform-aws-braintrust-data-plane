mock_provider "aws" {
  source = "./tests/mocks/aws"
}

run "deployment_tag_cannot_be_overridden" {
  command = plan
  module { source = "./modules/brainstore-ec2" }

  variables {
    deployment_name                       = "bt-test"
    license_key                           = "test-license"
    kms_key_arn                           = null
    vpc_id                                = "vpc-12345678"
    private_subnet_ids                    = ["subnet-12345678"]
    database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-test"
    database_host                         = "database.example.com"
    database_port                         = "5432"
    use_redis_replication_group           = false
    redis_host                            = "redis.example.com"
    redis_port                            = "6379"
    service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:token-test"
    ai_proxy_url_ssm_parameter            = "/bt-test/ai-proxy-url"
    brainstore_s3_bucket_arn              = "arn:aws:s3:::test-brainstore"
    lambda_responses_s3_bucket_arn        = "arn:aws:s3:::test-responses"
    code_bundle_s3_bucket_arn             = "arn:aws:s3:::test-code"
    brainstore_iam_role_name              = "bt-test-brainstore"
    brainstore_instance_security_group_id = "sg-12345678"
    writer_instance_count                 = 1
    fast_reader_instance_count            = 1
    custom_tags = {
      BraintrustDeploymentName = "another-deployment"
      Environment              = "test"
    }
  }

  assert {
    condition = alltrue([
      for asg in [aws_autoscaling_group.brainstore, aws_autoscaling_group.brainstore_writer[0], aws_autoscaling_group.brainstore_fast_reader[0]] :
      one([for tag in asg.tag : tag.value if tag.key == "BraintrustDeploymentName"]) == var.deployment_name
    ])
    error_message = "Every Brainstore ASG must retain the deployment tag required by the rollout helper and its IAM policy."
  }

  assert {
    condition = alltrue([
      for asg in [aws_autoscaling_group.brainstore, aws_autoscaling_group.brainstore_writer[0], aws_autoscaling_group.brainstore_fast_reader[0]] :
      one([for tag in asg.tag : tag.value if tag.key == "Environment"]) == "test"
    ])
    error_message = "Unrelated custom tags must be preserved on every Brainstore ASG."
  }
}
