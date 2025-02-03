variable "braintrust_org_name" {
  type        = string
  description = "The name of your organization in Braintrust (e.g. acme.com)"
}

variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names"
}

variable "service_vpc_id" {
  type        = string
  description = "The VPC ID for the lambda functions that are the main braintrust service"
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

variable "brainstore_hostname" {
  type        = string
  description = "Hostname for Brainstore"
}

variable "brainstore_port" {
  type        = number
  description = "Port for Brainstore"
  default     = 4000
}

variable "brainstore_s3_bucket_name" {
  type        = string
  description = "Name of the Brainstore S3 bucket"
}

variable "whitelisted_origins" {
  type        = list(string)
  description = "List of origins to whitelist for CORS"
}

variable "outbound_rate_limit_max_requests" {
  type        = number
  description = "The maximum number of requests per user allowed in the time frame specified by OutboundRateLimitMaxRequests. Setting to 0 will disable rate limits"
  default     = 0
}
variable "outbound_rate_limit_window_minutes" {
  type        = number
  description = "The time frame in minutes over which rate per-user rate limits are accumulated"
  default     = 1
}

variable "api_handler_provisioned_concurrency" {
  type        = number
  description = "The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost."
  default     = 1
}
