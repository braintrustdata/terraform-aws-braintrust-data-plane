variable "brainstore_license_key" {
  description = "Optional. Only needed if you enable create_ai_gateway in external-EKS mode (Brainstore EC2 is not created)."
  type        = string
  default     = null
  sensitive   = true
}
