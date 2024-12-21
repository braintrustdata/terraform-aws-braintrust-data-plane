variable "braintrust_org_name" {
  type        = string
  description = "The name of your organization in Braintrust (e.g. acme.com)"
}

variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names"
}

variable "service_security_group_ids" {
  type        = list(string)
  description = "The security group ids to apply to the lambda functions that are the main braintrust service"
}

variable "service_subnet_ids" {
  type        = list(string)
  description = "The subnet ids for the lambda functions that are the main braintrust service"
}

variable "postgres_username" {
  type        = string
  description = "The username of the postgres database"
}

variable "postgres_password" {
  type        = string
  description = "The password of the postgres database"
  sensitive   = true
}

variable "postgres_host" {
  type        = string
  description = "The host of the postgres database, optionally including the port. Format: host[:port]"
}

variable "redis_host" {
  type        = string
  description = "The host of the redis database"
}

variable "redis_port" {
  type        = string
  description = "The port of the redis database"
}

variable "use_quarantine_vpc" {
  type        = bool
  description = "Whether to use a quarantine VPC to allow running of user defined functions"
  default     = false
}

variable "quarantine_vpc_id" {
  type        = string
  description = "The ID of the quarantine VPC"
  default     = null
  validation {
    condition     = var.use_quarantine_vpc ? var.quarantine_vpc_id != null : true
    error_message = "Quarantine VPC ID is required when using quarantine VPC."
  }
}

variable "quarantine_vpc_default_security_group_id" {
  type        = string
  description = "The ID of the quarantine VPC default security group"
  default     = null
  validation {
    condition     = var.use_quarantine_vpc ? var.quarantine_vpc_default_security_group_id != null : true
    error_message = "Quarantine VPC default security group ID is required when using quarantine VPC."
  }
}

variable "quarantine_vpc_private_subnets" {
  type        = list(string)
  description = "The private subnets of the quarantine VPC"
  default     = []
  validation {
    condition     = var.use_quarantine_vpc ? length(var.quarantine_vpc_private_subnets) == 3 : true
    error_message = "Quarantine VPC must have 3 private subnets."
  }
}
