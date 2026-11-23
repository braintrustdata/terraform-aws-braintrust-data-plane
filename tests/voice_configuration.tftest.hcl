mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  deployment_name        = "bt-test"
  brainstore_license_key = "test-license"
  enable_quarantine_vpc  = true
}

run "voice_disabled_by_default" {
  command = plan
  assert {
    condition     = local.voice_session_ws_base_url == null
    error_message = "Voice must remain disabled unless explicitly enabled."
  }
}

run "voice_generated_cloudfront_origin" {
  command = plan
  variables { enable_voice_sessions = true }
  override_module {
    target  = module.ingress[0]
    outputs = { api_url = "https://d111111abcdef8.cloudfront.net" }
  }
  assert {
    condition     = local.voice_session_ws_base_url == "wss://d111111abcdef8.cloudfront.net"
    error_message = "Voice connections must use the generated public CloudFront hostname when no custom domain exists."
  }
}

run "rejects_voice_without_gateway" {
  command = plan
  variables {
    enable_voice_sessions = true
    enable_ai_gateway     = false
  }
  expect_failures = [var.enable_voice_sessions]
}

run "voice_disabled_allows_disabled_gateway" {
  command = plan
  variables { enable_ai_gateway = false }
}

run "voice_custom_origin_with_lambda_ingress" {
  command = plan
  variables {
    enable_voice_sessions  = true
    enable_ecs_api         = false
    custom_domain          = "api.example.com"
    custom_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
  }
  assert {
    condition     = local.voice_session_ws_base_url == "wss://api.example.com"
    error_message = "Voice connections must use the custom public hostname even with Lambda ingress."
  }
}

run "voice_private_origin" {
  command = plan
  variables {
    enable_voice_sessions              = true
    enable_private_dataplane           = true
    braintrust_api_alb_custom_domain   = "api.example.internal"
    braintrust_api_alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
  }
  assert {
    condition     = local.voice_session_ws_base_url == "wss://api.example.internal" && length(module.ingress) == 0
    error_message = "Private voice connections must use the HTTPS customer hostname without CloudFront."
  }
}

run "rejects_external_eks_voice" {
  command = plan
  variables {
    enable_voice_sessions            = true
    use_deployment_mode_external_eks = true
  }
  expect_failures = [var.enable_voice_sessions]
}
