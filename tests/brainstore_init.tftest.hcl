# Verify metadata ownership, pool gating, runtime secrets, and the EC2 size regression.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-automation/1234567890123456"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-automation/1234567890123456"
    }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/bt-automation"
    }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }
}

variables {
  deployment_name                       = "bt-automation-writer"
  license_key_secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  license_key_secret_version            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-automation-writer-database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-automation-writer-redis-url"
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-automation-writer-service-token"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-automation-writer-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-automation-writer-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-automation-writer-code-bundles"
  brainstore_iam_role_name              = "bt-automation-writer-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  ai_proxy_url_ssm_parameter            = "/bt-automation-writer/ai-proxy-url"
  automation_writer_instance_count      = 1
}

run "all_pools_use_cloudformation_init" {
  command = apply
  module { source = "./modules/brainstore-ec2" }

  variables {
    fast_reader_instance_count  = 1
    custom_post_install_script  = "echo init-post-install"
    custom_ca_bundle_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca"
  }

  assert {
    condition     = toset(keys(aws_cloudformation_stack.brainstore_init)) == toset(["reader", "writer", "fast_reader", "automation_writer"])
    error_message = "Each enabled pool needs its own metadata stack."
  }

  assert {
    condition = alltrue([
      for role, script in local.brainstore_init_scripts :
      jsondecode(aws_cloudformation_stack.brainstore_init[role].template_body).Resources.BrainstoreInit.Metadata["AWS::CloudFormation::Init"].config.files["/opt/braintrust/bootstrap.sh"].content == script &&
      strcontains(aws_cloudformation_stack.brainstore_init[role].name, substr(sha256(script), 0, 16)) &&
      aws_cloudformation_stack.brainstore_init[role].tags.BraintrustDeploymentName == var.deployment_name &&
      strcontains(script, "echo init-post-install") &&
      strcontains(script, "--env BRAINTRUST_CUSTOM_CA_BUNDLE")
    ])
    error_message = "Stacks must preserve bootstrap content, runtime CA delivery, tags, and content-addressed identity."
  }

  assert {
    condition = alltrue([
      for pair in [
        { role = "reader", user_data = aws_launch_template.brainstore.user_data },
        { role = "writer", user_data = aws_launch_template.brainstore_writer[0].user_data },
        { role = "fast_reader", user_data = aws_launch_template.brainstore_fast_reader[0].user_data },
        { role = "automation_writer", user_data = aws_launch_template.brainstore_automation_writer[0].user_data },
      ] :
      length(base64decode(pair.user_data)) < 16384 &&
      strcontains(base64decode(pair.user_data), "--stack '${aws_cloudformation_stack.brainstore_init[pair.role].id}'") &&
      strcontains(base64decode(pair.user_data), "--role '${var.brainstore_iam_role_name}'") &&
      !strcontains(base64decode(pair.user_data), "echo init-post-install")
    ])
    error_message = "Every launch template must have a small authenticated loader targeting its pool's metadata."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.brainstore_init.policy).Statement[0].Action == "cloudformation:DescribeStackResource" &&
      toset(jsondecode(aws_iam_role_policy.brainstore_init.policy).Statement[0].Resource) == toset([for stack in aws_cloudformation_stack.brainstore_init : stack.id])
    )
    error_message = "Instances may read metadata only from this deployment's bootstrap stacks."
  }
}

run "disabled_pools_have_no_metadata" {
  command = plan
  module { source = "./modules/brainstore-ec2" }
  variables {
    writer_instance_count            = 0
    fast_reader_instance_count       = 0
    automation_writer_instance_count = 0
  }
  assert {
    condition     = keys(aws_cloudformation_stack.brainstore_init) == ["reader"]
    error_message = "Disabled optional pools must not create bootstrap stacks."
  }
}

run "secret_rotation_changes_metadata_identity" {
  command = plan
  module { source = "./modules/brainstore-ec2" }
  variables {
    license_key_secret_version = "rotated-license-version"
  }
  assert {
    condition = alltrue([
      for role, script in local.brainstore_init_scripts :
      strcontains(script, "rotated-license-version") &&
      strcontains(aws_cloudformation_stack.brainstore_init[role].name, substr(sha256(script), 0, 16))
    ])
    error_message = "Version-pinned secrets must change the metadata stack identity and thus launch-template user data."
  }
}

run "bootstrap_larger_than_ec2_limit" {
  command = apply
  module { source = "./modules/brainstore-ec2" }
  variables {
    # Incompressible comments reproduce failure even with the old gzip loader.
    custom_post_install_script = join("\n", [for i in range(420) : "# ${sha256(tostring(i))}"])
    fast_reader_instance_count = 1
  }
  assert {
    condition = alltrue([
      for script in values(local.brainstore_init_scripts) : length(base64gzip(script)) > 21848
    ])
    error_message = "The regression fixture must exceed 16 KiB even when gzip-compressed."
  }
  assert {
    condition = alltrue([
      for template in [
        aws_launch_template.brainstore,
        aws_launch_template.brainstore_writer[0],
        aws_launch_template.brainstore_fast_reader[0],
        aws_launch_template.brainstore_automation_writer[0],
      ] : length(base64decode(template.user_data)) < 16384
    ])
    error_message = "Large bootstrap content must not increase EC2 user data beyond its limit."
  }
  assert {
    condition = alltrue([
      for stack in values(aws_cloudformation_stack.brainstore_init) : length(stack.template_body) <= 51200
    ])
    error_message = "Large bootstrap content must fit the inline CloudFormation template limit."
  }
}
