variable "deployment_name" {
  type = string
}

variable "fleets" {
  type = list(object({
    role                    = string
    asg_name                = string
    launch_template_id      = string
    launch_template_version = string
    desired_capacity        = number
    target_group_arn        = string
  }))
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}

variable "custom_tags" {
  type    = map(string)
  default = {}
}
