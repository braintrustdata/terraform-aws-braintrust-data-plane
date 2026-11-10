mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                       = "bt-test"
  license_key_secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  license_key_secret_version            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  kms_key_arn                           = null
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-test"
  database_host                         = "database.example.com"
  database_port                         = "5432"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-redis-url"
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:token-test"
  ai_proxy_url_ssm_parameter            = "/bt-test/ai-proxy-url"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::test-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::test-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::test-code"
  brainstore_iam_role_name              = "bt-test-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  writer_instance_count                 = 1
  fast_reader_instance_count            = 1
}

run "deployment_tag_cannot_be_overridden" {
  command = plan
  module { source = "./modules/brainstore-ec2" }

  variables {
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
    error_message = "Every Brainstore ASG must retain the deployment tag."
  }

  assert {
    condition = alltrue([
      for asg in [aws_autoscaling_group.brainstore, aws_autoscaling_group.brainstore_writer[0], aws_autoscaling_group.brainstore_fast_reader[0]] :
      one([for tag in asg.tag : tag.value if tag.key == "Environment"]) == "test"
    ])
    error_message = "Unrelated custom tags must be preserved on every Brainstore ASG."
  }

  assert {
    condition = (
      length(aws_autoscaling_group.brainstore_writer[0].instance_refresh) == 1 &&
      aws_autoscaling_group.brainstore_writer[0].instance_refresh[0].strategy == "Rolling"
    )
    error_message = "The ungated writer ASG must retain its own rolling instance refresh."
  }
}

run "instance_tags_reach_only_instances_and_volumes" {
  command = plan
  module { source = "./modules/brainstore-ec2" }

  variables {
    automation_writer_instance_count = 1
    custom_tags = {
      Environment = "test"
    }
    instance_tags = {
      ExampleInstanceTag       = "example-value"
      Environment              = "instance-override"
      BrainstoreRole           = "instance-override"
      BraintrustDeploymentName = "another-deployment"
    }
  }

  assert {
    condition = alltrue(flatten([
      for lt in [aws_launch_template.brainstore, aws_launch_template.brainstore_writer[0], aws_launch_template.brainstore_fast_reader[0], aws_launch_template.brainstore_automation_writer[0]] : [
        for spec in lt.tag_specifications :
        lookup(spec.tags, "ExampleInstanceTag", null) == (contains(["instance", "volume"], spec.resource_type) ? "example-value" : null)
      ]
    ]))
    error_message = "Instance tags must be set on the instance and volume tag specifications of every Brainstore launch template, and nowhere else in them."
  }

  assert {
    condition = alltrue([
      for lt in [aws_launch_template.brainstore, aws_launch_template.brainstore_writer[0], aws_launch_template.brainstore_fast_reader[0], aws_launch_template.brainstore_automation_writer[0]] :
      !contains(keys(lt.tags), "ExampleInstanceTag")
    ])
    error_message = "Instance tags must not be set on the launch template resources."
  }

  assert {
    condition = alltrue([
      for asg in [aws_autoscaling_group.brainstore, aws_autoscaling_group.brainstore_writer[0], aws_autoscaling_group.brainstore_fast_reader[0], aws_autoscaling_group.brainstore_automation_writer[0]] :
      !contains([for tag in asg.tag : tag.key], "ExampleInstanceTag")
    ])
    error_message = "Instance tags must not be set on the ASGs, so a change does not start a tag-triggered instance refresh."
  }

  assert {
    condition = alltrue(flatten([
      for lt in [aws_launch_template.brainstore, aws_launch_template.brainstore_writer[0], aws_launch_template.brainstore_fast_reader[0], aws_launch_template.brainstore_automation_writer[0]] : [
        for spec in lt.tag_specifications : (
          spec.tags["BraintrustDeploymentName"] == var.deployment_name &&
          spec.tags["Environment"] == "test" &&
          spec.tags["BrainstoreRole"] != "instance-override"
        )
      ]
    ]))
    error_message = "Module tags and custom tags must take precedence over instance tags."
  }
}
