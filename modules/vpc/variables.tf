variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
}

variable "public_subnet_1_az" {
  description = "Availability zone for the public subnet"
  type        = string
}

variable "private_subnet_1_cidr" {
  description = "CIDR block for private subnet 1"
  type        = string
}

variable "private_subnet_1_az" {
  description = "Availability zone for private subnet 1"
  type        = string
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for private subnet 2"
  type        = string
}

variable "private_subnet_2_az" {
  description = "Availability zone for private subnet 2"
  type        = string
}

variable "private_subnet_3_cidr" {
  description = "CIDR block for private subnet 3"
  type        = string
}

variable "private_subnet_3_az" {
  description = "Availability zone for private subnet 3"
  type        = string
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

variable "enable_brainstore_ec2_ssm" {
  description = "Optional. true will enable ssm (session manager) for the brainstore EC2s. Helpful for debugging without changing firewall rules"
  type        = bool
  default     = false
}

variable "flow_log" {
  description = <<-EOT
    VPC Flow Logs configuration. Disabled by default. When enabled, a destination is required:
      - destination_type = "s3": logs are written to `destination_arn` (a customer-provided S3 bucket).
        Leave `destination_arn` null to have the module create and manage a dedicated S3 bucket.
      - destination_type = "cloud-watch-logs": logs are written to `destination_arn` (a customer-provided
        CloudWatch log group). Leave `destination_arn` null to have the module create the log group.
        An IAM role for delivery is always created for the CloudWatch destination.
  EOT
  type = object({
    enabled                  = optional(bool, false)
    traffic_type             = optional(string, "ALL")
    destination_type         = optional(string, "s3")
    destination_arn          = optional(string, null)
    max_aggregation_interval = optional(number, 600)
    log_format               = optional(string, null)
    # Only used when the module manages the destination (destination_arn = null):
    retention_in_days = optional(number, 365)
    kms_key_arn       = optional(string, null)
  })
  default = {}

  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_log.traffic_type)
    error_message = "flow_log.traffic_type must be one of ALL, ACCEPT, or REJECT."
  }
  validation {
    condition     = contains(["s3", "cloud-watch-logs"], var.flow_log.destination_type)
    error_message = "flow_log.destination_type must be either \"s3\" or \"cloud-watch-logs\"."
  }
  validation {
    condition     = contains([60, 600], var.flow_log.max_aggregation_interval)
    error_message = "flow_log.max_aggregation_interval must be either 60 or 600 seconds."
  }
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.flow_log.retention_in_days)
    error_message = "flow_log.retention_in_days must be a valid CloudWatch Logs retention value."
  }
}
