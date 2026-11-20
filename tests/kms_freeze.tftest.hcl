mock_provider "aws" {
  source = "./tests/mocks/aws"
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

# The runs below fall into three scenarios, and each scenario's runs share one
# state and depend on the runs before them, so the order matters.
#
# Scenario 1, the default stack: the key is applied without the guard, then the
# guard is turned on in a later apply, which is the order MIGRATION_V8.md asks for.
# The plan-only runs after it check the guard against that state.

run "creates_no_guard_by_default" {
  command = plan
  module { source = "./modules/kms" }
  variables { deployment_name = "bt-test" }

  assert {
    condition     = length(terraform_data.kms_key_freeze) == 0
    error_message = "The freeze guard must not exist unless enable_kms_key_freeze is set."
  }
}

run "applies_key_without_guard" {
  command = apply
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = false
  }

  assert {
    condition     = length(terraform_data.kms_key_freeze) == 0
    error_message = "The freeze guard must not exist when enable_kms_key_freeze is false."
  }
}

run "installs_guard_against_unchanged_key" {
  command = apply
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
  }

  assert {
    condition     = length(terraform_data.kms_key_freeze) == 1
    error_message = "Turning on enable_kms_key_freeze must create exactly one guard."
  }

  assert {
    condition     = terraform_data.kms_key_freeze[0].output.alias_name == "alias/braintrust/bt-test"
    error_message = "The guard must store the alias name it protects."
  }
}

run "stores_every_protected_attribute" {
  command = plan
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
  }

  assert {
    condition = alltrue([
      for k in [
        "policy",
        "description",
        "is_enabled",
        "enable_key_rotation",
        "rotation_period_in_days",
        "tags",
        "tags_all",
        "region",
        "key_usage",
        "customer_master_key_spec",
        "multi_region",
        "custom_key_store_id",
        "xks_key_id",
        "key_id",
        "alias_name",
        "alias_target_key_id",
      ] : contains(keys(terraform_data.kms_key_freeze[0].output), k)
    ])
    error_message = "The guard must store every protected key and alias attribute."
  }
}

# This run has no assert block. It passes by not failing, which proves the guard's
# postcondition accepts a plan that changes nothing.
run "passes_plan_with_no_key_changes" {
  command = plan
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
  }
}

run "rejects_key_policy_change_when_frozen" {
  command = plan
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
    additional_key_policies = [{
      Sid       = "AllowTestRead"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::123456789012:root" }
      Action    = "kms:DescribeKey"
      Resource  = "*"
    }]
  }
  expect_failures = [terraform_data.kms_key_freeze]
}

run "rejects_tag_change_when_frozen" {
  command = plan
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
    custom_tags           = { Team = "security" }
  }
  expect_failures = [terraform_data.kms_key_freeze]
}

run "removes_guard_when_turned_off" {
  command = plan
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = false
    custom_tags           = { Team = "security" }
  }

  assert {
    condition     = length(terraform_data.kms_key_freeze) == 0
    error_message = "Turning off enable_kms_key_freeze must remove the guard."
  }
}

run "rejects_freeze_guard_with_caller_kms_key" {
  command = plan
  variables {
    deployment_name        = "bt-test"
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    brainstore_license_key = "test-license"
    kms_key_arn            = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    enable_kms_key_freeze  = true
  }
  expect_failures = [var.enable_kms_key_freeze]
}

# Scenario 2, the tag re-baseline: this is how a frozen stack changes a tag. The
# key gets the tag while the guard is off, then the guard is turned back on, which
# stores the new values, and later plans are checked against that new baseline.

run "applies_key_with_custom_tags_before_freeze" {
  command = apply
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = false
    custom_tags           = { Team = "security" }
  }
}

run "freezes_key_with_custom_tags" {
  command = apply
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
    custom_tags           = { Team = "security" }
  }
}

run "passes_unchanged_plan_after_rebaseline" {
  command = plan
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
    custom_tags           = { Team = "security" }
  }
}

run "rejects_dropping_a_tag_after_rebaseline" {
  command = plan
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
    custom_tags           = {}
  }
  expect_failures = [terraform_data.kms_key_freeze]
}

# Scenario 3, a new stack: the guard is turned on in the apply that creates the
# key. This scenario uses its own state, `new_stack`. These runs are mocked only,
# so they don't show how the real create-then-read path behaves, where the
# provider fills in values after the apply. MIGRATION_V8.md says to turn the
# guard on in a later apply for that reason.

run "freezes_key_in_the_apply_that_creates_it" {
  command   = apply
  state_key = "new_stack"
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
  }
}

run "passes_unchanged_plan_after_freezing_at_creation" {
  command   = plan
  state_key = "new_stack"
  module { source = "./modules/kms" }
  variables {
    deployment_name       = "bt-test"
    enable_kms_key_freeze = true
  }
}
