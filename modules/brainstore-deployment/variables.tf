variable "deployment_name" {
  type = string
}

variable "version_tag" {
  description = "The release tag shared with the active API deployment."
  type        = string
}

variable "fleets" {
  description = "Fleets to roll out. Each sets either an exact desired_capacity or, for autoscaled ASGs, min_capacity and max_capacity."
  type = list(object({
    role                    = string
    asg_name                = string
    launch_template_id      = string
    launch_template_version = string
    desired_capacity        = optional(number)
    min_capacity            = optional(number)
    max_capacity            = optional(number)
    target_group_arn        = string
  }))

  validation {
    condition = alltrue([
      for fleet in var.fleets :
      fleet.desired_capacity != null ? (fleet.min_capacity == null && fleet.max_capacity == null) : (fleet.min_capacity != null && fleet.max_capacity != null)
    ])
    error_message = "Each fleet must set either desired_capacity, or both min_capacity and max_capacity."
  }
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}

variable "custom_tags" {
  type    = map(string)
  default = {}
}
