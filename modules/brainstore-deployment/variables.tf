variable "deployment_name" {
  type = string
}

variable "version_tag" {
  description = "The release tag shared with the active API deployment."
  type        = string
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

variable "waiter_role_arn" {
  description = "ARN of the waiter function's execution role. Pass the brainstore_deployment_waiter_role_arn output of modules/iam so the function waits for the role's policy."
  type        = string
}

variable "custom_tags" {
  type    = map(string)
  default = {}
}
