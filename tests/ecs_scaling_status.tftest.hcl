mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  deployment_name                = "bt-test"
  vpc_id                         = "vpc-12345678"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
  database_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
  code_bundle_s3_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_s3_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
}

run "non_ecs_creates_no_scaling_permissions" {
  command = plan
  module { source = "./modules/services-common" }

  assert {
    condition     = length(aws_iam_role_policy.api_handler_cloudwatch_metrics) == 0
    error_message = "Non-ECS deployments must not receive ECS autoscaling permissions."
  }
}

run "ecs_status_reads_are_scoped_to_the_deployment_cluster" {
  command = plan
  module { source = "./modules/services-common" }

  variables {
    enable_ecs = true
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_cloudwatch_metrics[0].policy).Statement[1].Effect == "Allow" && jsondecode(aws_iam_role_policy.api_handler_cloudwatch_metrics[0].policy).Statement[1].Action == ["ecs:DescribeTasks"]
    error_message = "ECS autoscaling must grant task status reads only."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_cloudwatch_metrics[0].policy).Statement[1].Resource == "arn:aws:ecs:us-east-1:123456789012:task/bt-test/*"
    error_message = "Task status reads must be restricted to tasks in this deployment's account, region, and cluster."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_cloudwatch_metrics[0].policy).Statement[1].Condition.ArnEquals["ecs:cluster"] == "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
    error_message = "Task status reads must require the deployment's own ECS cluster."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_cloudwatch_metrics[0].policy).Statement[0].Action == ["cloudwatch:PutMetricData"] && jsondecode(aws_iam_role_policy.api_handler_cloudwatch_metrics[0].policy).Statement[0].Condition.StringEquals["cloudwatch:namespace"] == "Braintrust/Api"
    error_message = "CloudWatch metric publishing must remain restricted to the Braintrust/Api namespace."
  }
}
