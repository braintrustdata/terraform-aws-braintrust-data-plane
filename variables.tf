locals {
  # Lookup and choose an AZ if not provided
  private_subnet_1_az = var.private_subnet_1_az != null ? var.private_subnet_1_az : data.aws_availability_zones.available.names[0]
  private_subnet_2_az = var.private_subnet_2_az != null ? var.private_subnet_2_az : data.aws_availability_zones.available.names[1]
  private_subnet_3_az = var.private_subnet_3_az != null ? var.private_subnet_3_az : data.aws_availability_zones.available.names[2]
  public_subnet_1_az  = var.public_subnet_1_az != null ? var.public_subnet_1_az : data.aws_availability_zones.available.names[0]

  # Lookup and choose an AZ if not provided for Quarantine VPC
  quarantine_private_subnet_1_az = var.quarantine_private_subnet_1_az != null ? var.quarantine_private_subnet_1_az : data.aws_availability_zones.available.names[0]
  quarantine_private_subnet_2_az = var.quarantine_private_subnet_2_az != null ? var.quarantine_private_subnet_2_az : data.aws_availability_zones.available.names[1]
  quarantine_private_subnet_3_az = var.quarantine_private_subnet_3_az != null ? var.quarantine_private_subnet_3_az : data.aws_availability_zones.available.names[2]
  quarantine_public_subnet_1_az  = var.quarantine_public_subnet_1_az != null ? var.quarantine_public_subnet_1_az : data.aws_availability_zones.available.names[0]
}

variable "braintrust_org_name" {
  type        = string
  description = "The name of your organization in Braintrust (e.g. acme.com)"
}

variable "deployment_name" {
  type        = string
  default     = "braintrust"
  description = "Name of this Braintrust deployment. Will be included in tags and prefixes in resources names. Lowercase letters and hyphens only."
  validation {
    condition     = can(regex("^[a-z-]+$", var.deployment_name))
    error_message = "The deployment_name must contain only lowercase letters and hyphens in order to be compatible with AWS resource naming restrictions."
  }
}

## NETWORKING
variable "vpc_cidr" {
  type        = string
  default     = "172.29.0.0/16"
  description = "CIDR block for the VPC"
}

variable "private_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the first available zone"
}

variable "private_subnet_2_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the second available zone"
}

variable "private_subnet_3_az" {
  type        = string
  default     = null
  description = "Availability zone for the third private subnet. Leave blank to choose the third available zone"
}

variable "public_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the public subnet. Leave blank to choose the first available zone"
}

variable "enable_quarantine" {
  type        = bool
  description = "Enable optional Quarantine VPC. If enabled, user defined functions run inside of this VPC."
  default     = false
}

variable "quarantine_vpc_cidr" {
  type        = string
  default     = "172.30.0.0/16"
  description = "CIDR block for the Quarantined VPC"
}

variable "quarantine_private_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the first available zone"
}

variable "quarantine_private_subnet_2_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the second available zone"
}

variable "quarantine_private_subnet_3_az" {
  type        = string
  default     = null
  description = "Availability zone for the third private subnet. Leave blank to choose the third available zone"
}

variable "quarantine_public_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the public subnet. Leave blank to choose the first available zone"
}


## Database
variable "postgres_instance_type" {
  description = "Instance type for the RDS instance."
  type        = string
  default     = "db.t4g.xlarge"
}

variable "postgres_storage_size" {
  description = "Storage size (in GB) for the RDS instance."
  type        = number
  default     = 100
}

variable "postgres_storage_type" {
  description = "Storage type for the RDS instance."
  type        = string
  default     = "gp3"
}

variable "postgres_storage_iops" {
  description = "Storage IOPS for the RDS instance. Only applicable if storage_type is io1, io2, or gp3."
  type        = number
  default     = null
}

variable "postgres_storage_throughput" {
  description = "Throughput for the RDS instance. Only applicable if storage_type is gp3."
  type        = number
  default     = null
}

variable "postgres_version" {
  description = "PostgreSQL engine version for the RDS instance."
  type        = string
  default     = "15.7"
}

## Redis
variable "redis_instance_type" {
  description = "Instance type for the Redis cluster"
  type        = string
  default     = "cache.t4g.small"
}

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

## Services

variable "api_handler_provisioned_concurrency" {
  description = "The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost."
  type        = number
  default     = 0
}

variable "whitelisted_origins" {
  description = "List of origins to whitelist for CORS"
  type        = list(string)
  default     = []
}

variable "outbound_rate_limit_max_requests" {
  description = "The maximum number of requests per user allowed in the time frame specified by OutboundRateLimitMaxRequests. Setting to 0 will disable rate limits"
  type        = number
  default     = 0
}

variable "outbound_rate_limit_window_minutes" {
  description = "The time frame in minutes over which rate per-user rate limits are accumulated"
  type        = number
  default     = 1
}
