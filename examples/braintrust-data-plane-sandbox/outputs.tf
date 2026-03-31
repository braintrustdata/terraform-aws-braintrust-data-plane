output "api_url" {
  value       = module.braintrust-data-plane.api_url
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL."
}
