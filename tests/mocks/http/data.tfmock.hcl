# Shared HTTP mock defaults for Lambda version lookups in modules/services.
# Loaded via: mock_provider "http" { source = "./tests/mocks/http" }

mock_data "http" {
  defaults = {
    status_code   = 200
    response_body = "lambda/APIHandler/a1b2c3d4e5f6.zip"
    response_headers = {
      "Content-Type" = "text/plain"
    }
  }
}
