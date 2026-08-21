variable "enable_loop_runtime" {
  type        = bool
  description = "Deploy the dedicated Loop runtime ECS/Fargate service (hosted Loop) and its MicroVM sandbox. Requires the ECS API data plane, Brainstore, and a Gateway (use_global_ai_gateway_origin or enable_ai_gateway). Loop v2 cannot use the AI Proxy Lambda alone."
  default     = false

  validation {
    condition     = !var.enable_loop_runtime || var.enable_brainstore
    error_message = "enable_loop_runtime requires enable_brainstore = true (the Loop runtime reads from Brainstore)."
  }

  validation {
    condition     = !var.enable_loop_runtime || !var.use_deployment_mode_external_eks
    error_message = "enable_loop_runtime is not supported with use_deployment_mode_external_eks = true (the Loop runtime requires the in-VPC ECS API data plane)."
  }

  validation {
    condition     = !var.enable_loop_runtime || var.use_global_ai_gateway_origin || var.enable_ai_gateway
    error_message = "enable_loop_runtime requires a Gateway: set use_global_ai_gateway_origin (public hosted Gateway) or enable_ai_gateway (private Gateway). create_ai_gateway alone is not enough — Loop v2 cannot use the AI Proxy Lambda without GATEWAY_URL."
  }
}

variable "loop_runtime_version_override" {
  type        = string
  description = "Pin the Loop runtime container image and MicroVM guest artifact to a specific version tag. Defaults to modules/loop-runtime-ecs/VERSIONS.json."
  default     = null
}

variable "loop_runtime_task_cpu" {
  type        = number
  description = "CPU units for the Loop runtime ECS task."
  default     = 2048
}

variable "loop_runtime_task_memory" {
  type        = number
  description = "Memory (MiB) for the Loop runtime ECS task."
  default     = 8192
}

variable "loop_runtime_ephemeral_storage_gib" {
  type        = number
  description = "Task ephemeral storage in GiB (21-200) for the Loop runtime. Null uses the Fargate default (20)."
  default     = null
}

variable "loop_runtime_min_capacity" {
  type        = number
  description = "Minimum number of Loop runtime ECS tasks."
  default     = 1
}

variable "loop_runtime_max_capacity" {
  type        = number
  description = "Maximum number of Loop runtime ECS tasks."
  default     = 4
}

variable "loop_runtime_target_cpu_utilization" {
  type        = number
  description = "Target average CPU utilization percentage for Loop runtime autoscaling."
  default     = 40
}

variable "loop_runtime_target_memory_utilization" {
  type        = number
  description = "Target average memory utilization percentage for Loop runtime autoscaling."
  default     = 50
}

variable "loop_runtime_log_retention_days" {
  type        = number
  description = "CloudWatch log retention days for Loop runtime container logs."
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.loop_runtime_log_retention_days)
    error_message = "loop_runtime_log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "loop_runtime_enable_execute_command" {
  type        = bool
  description = "Enable ECS Exec on the Loop runtime service."
  default     = false
}

variable "loop_runtime_alb_deregistration_delay" {
  type        = number
  description = "Deregistration delay (seconds) for the Loop runtime ALB target group."
  default     = 900
}

variable "loop_runtime_org_name" {
  type        = string
  description = "Org this Loop runtime serves (ORG_NAME). '*' allows any."
  default     = "*"
}

variable "loop_runtime_extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables merged into the Loop runtime container."
  default     = {}
}

variable "loop_runtime_microvm_minimum_memory_mib" {
  type        = number
  description = "Minimum memory (MiB) provisioned for sandbox MicroVMs."
  default     = 2048
}

variable "loop_runtime_microvm_max_idle_duration_seconds" {
  type        = number
  description = "Seconds without endpoint traffic before a sandbox MicroVM auto-suspends."
  default     = 900
}

variable "loop_runtime_microvm_suspended_duration_seconds" {
  type        = number
  description = "Seconds a suspended sandbox MicroVM remains resumable before termination."
  default     = 28800
}

variable "loop_runtime_microvm_maximum_duration_seconds" {
  type        = number
  description = "Maximum sandbox MicroVM lifetime in running or suspended states."
  default     = 28800
}

variable "loop_runtime_microvm_auth_token_expiration_minutes" {
  type        = number
  description = "Endpoint auth token lifetime in minutes for sandbox MicroVM invocations."
  default     = 30
}

variable "enable_loop_runtime_microvm_runtime_logs" {
  type        = bool
  description = "Export Loop runtime MicroVM stdout/stderr to CloudWatch (can include sandbox output)."
  default     = false
}

variable "loop_runtime_sandbox_egress_mode" {
  type        = string
  description = "Outbound-network mode for Loop runtime sandbox MicroVMs. Exactly \"internet\" uses AWS-managed Internet egress; any other value uses a restricted connector with no outbound network access."
  default     = "internet"
}
