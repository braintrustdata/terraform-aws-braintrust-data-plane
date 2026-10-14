# Preconditions fail the plan. check blocks only warn, so a three-zone
# bring-your-own VPC could omit subnet 3 and still deploy.
resource "terraform_data" "network_zone_requirements" {
  lifecycle {
    precondition {
      condition     = length(local.az_names) >= 2
      error_message = "The data plane needs at least two availability zones."
    }

    precondition {
      condition = local.private_subnet_3_az == null || (
        local.private_subnet_3_az != local.private_subnet_1_az &&
        local.private_subnet_3_az != local.private_subnet_2_az
      )
      error_message = "private_subnet_3_az must differ from the first two private subnet zones."
    }

    precondition {
      condition = local.quarantine_private_subnet_3_az == null || (
        local.quarantine_private_subnet_3_az != local.quarantine_private_subnet_1_az &&
        local.quarantine_private_subnet_3_az != local.quarantine_private_subnet_2_az
      )
      error_message = "quarantine_private_subnet_3_az must differ from the first two quarantine private subnet zones."
    }

    precondition {
      condition     = var.create_vpc || length(local.az_names) < 3 || var.existing_private_subnet_3_id != null
      error_message = "existing_private_subnet_3_id is required when the region has three or more availability zones."
    }

    precondition {
      condition     = var.existing_quarantine_vpc_id == null || length(local.az_names) < 3 || var.existing_quarantine_private_subnet_3_id != null
      error_message = "existing_quarantine_private_subnet_3_id is required when the region has three or more availability zones."
    }

    precondition {
      condition     = var.loop_runtime_sandbox_existing_vpc_id == null || length(local.az_names) < 3 || var.loop_runtime_sandbox_existing_private_subnet_3_id != null
      error_message = "loop_runtime_sandbox_existing_private_subnet_3_id is required when the region has three or more availability zones."
    }
  }
}
