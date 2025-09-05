variable "deployment_name" {
  type        = string
  description = "The name of the deployment"
}

variable "instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore reader nodes.  Recommended Graviton instance type with 16GB of memory and a local SSD for cache data."
  default     = "c8gd.4xlarge"
}

variable "license_key" {
  type        = string
  description = "The license key for the Brainstore"
  validation {
    condition     = length(var.license_key) > 0
    error_message = "The license key cannot be empty."
  }
}

variable "instance_count" {
  type        = number
  description = "The number of reader instances to create"
  default     = 2
}

variable "port" {
  type        = number
  description = "The port to use for the Brainstore"
  default     = 4000
}

variable "version_override" {
  type        = string
  description = "Lock Brainstore on a specific version. Don't set this unless instructed by Braintrust."
  default     = null
}

variable "instance_key_pair_name" {
  type        = string
  description = "Optional. The name of the key pair to use for the Brainstore instances"
  default     = null
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for encrypting the Brainstore disks and S3 bucket. If not provided, AWS managed keys will be used."
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where Brainstore resources will be created"
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access the Brainstore ELB. Format: { name = <security_group_id> }"
  default     = {}
}

variable "authorized_security_groups_ssh" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access Brainstore instances via SSH. Format: { name = <security_group_id> }"
  default     = {}
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "The IDs of the private subnets where Brainstore instances will be launched"
}

# Brainstore depends on the existing Postgres database and Redis instance.
variable "database_secret_arn" {
  type        = string
  description = "The ARN of the secret containing database credentials"
}

variable "database_host" {
  type        = string
  description = "The hostname of the database"
}

variable "database_port" {
  type        = string
  description = "The port of the database"
}

variable "redis_host" {
  type        = string
  description = "The hostname of the Redis instance"
}

variable "redis_port" {
  type        = string
  description = "The port of the Redis instance"
}

variable "extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables to set for Brainstore reader or dual use nodes"
  default     = {}
}

variable "extra_env_vars_writer" {
  type        = map(string)
  description = "Extra environment variables to set for Brainstore writer nodes if enabled"
  default     = {}
}

variable "writer_instance_count" {
  type        = number
  description = "The number of dedicated writer nodes to create"
  default     = 1
}

variable "writer_instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore writer nodes"
  default     = "c8gd.8xlarge"
}

variable "brainstore_disable_optimization_worker" {
  type        = bool
  description = "Whether to disable the optimization worker in Brainstore"
  default     = false
}

variable "monitoring_telemetry" {
  description = <<-EOT
    The telemetry to send to Braintrust's control plane to monitor your deployment. Should be in the form of comma-separated values.

    Available options:
    - status: Health check information (default)
    - metrics: System metrics (CPU/memory) and Braintrust-specific metrics like indexing lag (default)
    - usage: Billing usage telemetry for aggregate usage metrics
    - memprof: Memory profiling statistics and heap usage patterns
    - logs: Application logs
    - traces: Distributed tracing data
  EOT
  type        = string
  default     = "status,metrics"

  validation {
    condition = var.monitoring_telemetry == "" || alltrue([
      for item in split(",", var.monitoring_telemetry) :
      contains(["metrics", "logs", "traces", "status", "memprof", "usage"], trimspace(item))
    ])
    error_message = "The monitoring_telemetry value must be a comma-separated list containing only: metrics, logs, traces, status, memprof, usage."
  }
}

variable "s3_bucket_retention_days" {
  type        = number
  description = "The number of days to retain non-current S3 objects. e.g. deleted objects"
  default     = 7
}

variable "internal_observability_api_key" {
  type        = string
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  default     = ""
}

variable "internal_observability_env_name" {
  type        = string
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  default     = ""
}

variable "internal_observability_region" {
  type        = string
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  default     = "us5"
}

# Autoscaling Configuration
variable "enable_autoscaling" {
  type        = bool
  description = "Enable CPU-based autoscaling for Brainstore instances (readers when writers enabled, reader/writer when writers disabled)"
  default     = false
}

variable "autoscaling_min_capacity" {
  type        = number
  description = "Minimum number of Brainstore instances when autoscaling is enabled"
  default     = 2
}

variable "autoscaling_max_capacity" {
  type        = number
  description = "Maximum number of Brainstore instances when autoscaling is enabled"
  default     = 4
}

variable "autoscaling_desired_capacity" {
  type        = number
  description = "Desired number of Brainstore instances when autoscaling is enabled"
  default     = 2
}

variable "autoscaling_cpu_scale_up_threshold" {
  type        = number
  description = "CPU utilization threshold percentage to trigger scale up"
  default     = 70
}

variable "autoscaling_cpu_scale_down_threshold" {
  type        = number
  description = "CPU utilization threshold percentage to trigger scale down"
  default     = 30
}

variable "autoscaling_cpu_period" {
  type        = number
  description = "Period in seconds for CPU metric evaluation"
  default     = 300
}

variable "autoscaling_cpu_evaluation_periods" {
  type        = number
  description = "Number of evaluation periods for CPU metric before triggering alarm"
  default     = 2
}

variable "autoscaling_adjustment_type" {
  type        = string
  description = "The type of adjustment to make when scaling"
  default     = "ChangeInCapacity"
  validation {
    condition     = contains(["ChangeInCapacity", "ExactCapacity", "PercentChangeInCapacity"], var.autoscaling_adjustment_type)
    error_message = "The adjustment_type must be one of: ChangeInCapacity, ExactCapacity, PercentChangeInCapacity."
  }
}

variable "autoscaling_step_scaling_up" {
  type = list(object({
    metric_interval_lower_bound = number
    metric_interval_upper_bound = number
    scaling_adjustment          = number
  }))
  description = "Step scaling adjustments for scale up actions"
  default = [
    {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = null
      scaling_adjustment          = 1
    }
  ]
}

variable "autoscaling_step_scaling_down" {
  type = list(object({
    metric_interval_lower_bound = number
    metric_interval_upper_bound = number
    scaling_adjustment          = number
  }))
  description = "Step scaling adjustments for scale down actions"
  default = [
    {
      metric_interval_lower_bound = null
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  ]
}

# Writer Autoscaling Configuration
variable "writer_enable_autoscaling" {
  type        = bool
  description = "Enable CPU-based autoscaling for Brainstore writer instances"
  default     = false
}

variable "writer_autoscaling_min_capacity" {
  type        = number
  description = "Minimum number of Brainstore writer instances when autoscaling is enabled"
  default     = 1
}

variable "writer_autoscaling_max_capacity" {
  type        = number
  description = "Maximum number of Brainstore writer instances when autoscaling is enabled"
  default     = 2
}

variable "writer_autoscaling_desired_capacity" {
  type        = number
  description = "Desired number of Brainstore writer instances when autoscaling is enabled"
  default     = 1
}

variable "writer_autoscaling_cpu_scale_up_threshold" {
  type        = number
  description = "CPU utilization threshold percentage to trigger scale up for writers"
  default     = 70
}

variable "writer_autoscaling_cpu_scale_down_threshold" {
  type        = number
  description = "CPU utilization threshold percentage to trigger scale down for writers"
  default     = 30
}

variable "writer_autoscaling_cpu_period" {
  type        = number
  description = "Period in seconds for CPU metric evaluation for writers"
  default     = 300
}

variable "writer_autoscaling_cpu_evaluation_periods" {
  type        = number
  description = "Number of evaluation periods for CPU metric before triggering alarm for writers"
  default     = 2
}


variable "writer_autoscaling_adjustment_type" {
  type        = string
  description = "The type of adjustment to make when scaling writers"
  default     = "ChangeInCapacity"
  validation {
    condition     = contains(["ChangeInCapacity", "ExactCapacity", "PercentChangeInCapacity"], var.writer_autoscaling_adjustment_type)
    error_message = "The adjustment_type must be one of: ChangeInCapacity, ExactCapacity, PercentChangeInCapacity."
  }
}

variable "writer_autoscaling_step_scaling_up" {
  type = list(object({
    metric_interval_lower_bound = number
    metric_interval_upper_bound = number
    scaling_adjustment          = number
  }))
  description = "Step scaling adjustments for scale up actions for writers"
  default = [
    {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = null
      scaling_adjustment          = 1
    }
  ]
}

variable "writer_autoscaling_step_scaling_down" {
  type = list(object({
    metric_interval_lower_bound = number
    metric_interval_upper_bound = number
    scaling_adjustment          = number
  }))
  description = "Step scaling adjustments for scale down actions for writers"
  default = [
    {
      metric_interval_lower_bound = null
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  ]
}
