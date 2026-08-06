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

variable "s3_vpc_endpoint_resource_org_ids" {
  type        = list(string)
  description = <<-EOT
    Optional allowlist of AWS Organization IDs for the S3 VPC gateway endpoint policy (aws:ResourceOrgID).
    When non-empty, takes precedence over s3_vpc_endpoint_resource_account_ids.
    When both this and s3_vpc_endpoint_resource_account_ids are empty (default), the endpoint allows all S3 traffic.
  EOT
  default     = []

  validation {
    condition = alltrue([
      for org_id in var.s3_vpc_endpoint_resource_org_ids :
      can(regex("^o-[a-z0-9]{10,32}$", org_id))
    ])
    error_message = "s3_vpc_endpoint_resource_org_ids entries must be AWS Organization IDs of the form o-<10-32 lowercase alphanumeric characters>."
  }
}

variable "s3_vpc_endpoint_resource_account_ids" {
  type        = list(string)
  description = <<-EOT
    Optional allowlist of AWS account IDs for the S3 VPC gateway endpoint policy (aws:ResourceAccount).
    Used only when s3_vpc_endpoint_resource_org_ids is empty; ignored when org IDs are set.
    When both this and s3_vpc_endpoint_resource_org_ids are empty (default), the endpoint allows all S3 traffic.
    The current AWS account is always included automatically when this restriction is active.
  EOT
  default     = []

  validation {
    condition = alltrue([
      for account_id in var.s3_vpc_endpoint_resource_account_ids :
      can(regex("^[0-9]{12}$", account_id))
    ])
    error_message = "s3_vpc_endpoint_resource_account_ids entries must be 12-digit AWS account IDs."
  }
}
