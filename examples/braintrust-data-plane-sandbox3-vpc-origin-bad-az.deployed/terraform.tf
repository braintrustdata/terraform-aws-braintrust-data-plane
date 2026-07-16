terraform {
  backend "s3" {
    region  = "us-west-2"
    bucket  = "erikdw-sandbox-terraform-state-982534393296-us-west-2-an"
    key     = "erikdw-sandbox3.tfstate"
    profile = "sandbox-usw2"

    use_lockfile = true
  }
}
