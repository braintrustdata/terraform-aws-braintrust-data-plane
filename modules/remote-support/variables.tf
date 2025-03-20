variable "deployment_name" {
  description = "Name of the deployment. Used for resource naming"
  type        = string
}

variable "enable_braintrust_support_logs_access" {
  description = "Enable Cloudwatch logs access for Braintrust staff"
  type        = bool
  default     = false
}

variable "enable_braintrust_support_shell_access" {
  description = "Enable Bastion shell access for Braintrust staff. This will create a bastion host and a security group that allows EC2 instance connect access from the Braintrust IAM Role."
  type        = bool
  default     = false
}

variable "bastion_allowed_cidrs" {
  description = "List of CIDRs that are allowed to access the bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vpc_id" {
  description = "ID of the VPC where the bastion host will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs where the bastion host can be deployed"
  type        = list(string)
}

variable "database_host" {
  description = "Hostname of the database"
  type        = string
}

variable "database_secret_arn" {
  description = "ARN of the database credentials secret"
  type        = string
}

variable "clickhouse_host" {
  description = "Hostname of the ClickHouse instance"
  type        = string
}

variable "clickhouse_secret_arn" {
  description = "ARN of the ClickHouse credentials secret"
  type        = string
}

variable "redis_host" {
  description = "Hostname of the Redis instance"
  type        = string
}

variable "redis_port" {
  description = "Port of the Redis instance"
  type        = number
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for encrypting the bastion host"
  type        = string
}

variable "lambda_function_arns" {
  description = "List of Lambda function ARNs to make available to the bastion host"
  type        = list(string)
  default     = []
}
