terraform {
  backend "s3" {
    region       = "us-east-1"
    bucket       = "braintrust-terraform-state"
    use_lockfile = true
    key          = "env/sandbox/dataplane-evignanker/terraform.tfstate"
  }
}
