# Focused replacement-order fixture for the fixed-name Loop runtime ECS service.
# Testing the submodule directly keeps all optional upstream IDs known while
# retaining the repository's mocked AWS provider and real Terraform graph.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

override_resource {
  target = aws_iam_role.task_execution
  values = {
    arn  = "arn:aws:iam::123456789012:role/bt-test-loop-runtime-task-exec"
    id   = "bt-test-loop-runtime-task-exec"
    name = "bt-test-loop-runtime-task-exec"
  }
}

override_resource {
  target = aws_iam_role.task
  values = {
    arn  = "arn:aws:iam::123456789012:role/bt-test-loop-runtime-task"
    id   = "bt-test-loop-runtime-task"
    name = "bt-test-loop-runtime-task"
  }
}

variables {
  deployment_name                = "bt-test"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id                         = "vpc-test"
  private_subnet_ids             = ["subnet-a", "subnet-b"]
  ecs_cluster_arn                = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name               = "bt-test"
  container_image                = "public.ecr.aws/braintrust/loop-runtime:test"
  ephemeral_storage_gib          = 21
  target_group_arn               = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/loop-runtime/test"
  alb_security_group_id          = "sg-alb"
  loop_runtime_http_listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/loop-runtime/test/listener"
  database_url_secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  function_tools_secret_arn      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  brainstore_s3_bucket_name      = "brainstore-test"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::brainstore-test"
  code_bundle_bucket             = "code-bundle-test"
  code_bundle_bucket_arn         = "arn:aws:s3:::code-bundle-test"
  brainstore_reader_url          = "http://brainstore.test:4000"
  ai_proxy_url                   = "https://ai-proxy.test"
  braintrust_api_url             = "https://api.test"
}

run "seed_mocked_loop_runtime_state" {
  command = apply

  module {
    source = "./modules/loop-runtime-ecs"
  }
}

run "force_fixed_name_loop_runtime_replacement" {
  command = plan

  module {
    source = "./modules/loop-runtime-ecs"
  }

  plan_options {
    refresh = false
    replace = [
      aws_ecs_service.loop_runtime,
    ]
  }
}
