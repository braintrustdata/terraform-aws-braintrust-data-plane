variable "brainstore_license_key" {
  description = "The license key for the Brainstore instance. You can get this from the Braintrust UI in Settings > Data Plane."
  type        = string
  # Note: For actual deployments, set this via environment variable or terraform.tfvars
  # For testing: TF_VAR_brainstore_license_key=dummy terraform validate
}
