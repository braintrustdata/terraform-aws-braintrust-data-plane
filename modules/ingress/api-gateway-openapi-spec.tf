# The API Gateway OpenAPI Spec
# All new paths should be added manually here.
locals {
  snippet_api_json_method = {
    consumes = ["application/json"]
    produces = ["application/json"]
    responses = {
      "200" = {
        description = "200 response"
        schema = {
          title = "Empty Schema"
          type  = "object"
        }
      }
    }
    x-amazon-apigateway-integration = local.snippet_api_gateway_integration
  }
  snippet_api_json_text_method = merge(local.snippet_api_json_method, {
    consumes = ["application/json", "text/plain"]
  })
  snippet_api_gateway_integration = {
    "uri"                 = "arn:aws:apigateway:${data.aws_region.current.region}:lambda:path/2015-03-31/functions/${var.api_handler_function_arn}/invocations"
    "type"                = "aws_proxy"
    "httpMethod"          = "POST"
    "contentHandling"     = "CONVERT_TO_TEXT"
    "passthroughBehavior" = "when_no_match"
    "responses" = {
      "default" = {
        "statusCode" = "200"
      }
    }
  }

  # OpenAPI spec for API Gateway
  api_gateway_openapi_spec = {
    openapi = "3.0.1"

    info = {
      title   = "${var.deployment_name}-API"
      version = "1.0"
    }

    schemes = ["https"]

    paths = {
      "/" = {
        get = local.snippet_api_json_text_method
      }
      "/api/{object_type}" = {
        for method in ["get", "options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/api/{object_type}/{action}" = {
        for method in ["get", "options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "action"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/attachment" = {
        for method in ["get", "options", "post"] : method => local.snippet_api_json_text_method
      }
      "/attachment/status" = {
        for method in ["get", "options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/backfill/disable" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/backfill/enable" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/backfill/optimize" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/backfill/run" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/backfill/status" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/backfill/status/object/{object_id}" = {
        for method in ["get", "options"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/brainstore/backfill/status/project/{project_id}" = {
        for method in ["get", "options"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "project_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/brainstore/backfill/track" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/segment/{segment_id}" = {
        for method in ["get", "options"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "segment_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/broadcast-key" = {
        for method in ["get", "options", "post"] : method => local.snippet_api_json_text_method
      }
      "/btql" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/crud/base_experiments" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/dataset-summary" = {
        for method in ["get", "options", "post"] : method => local.snippet_api_json_text_method
      }
      "/db-health" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/experiment-comparison2" = {
        for method in ["get", "options", "post"] : method => local.snippet_api_json_text_method
      }
      "/flush-object-cache" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/flush-org-object-cache" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/function-env/{object_type}/{object_id}" = {
        for method in ["delete", "get", "options", "patch", "post", "put"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "object_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/insert-functions" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/logs" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/logs2" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/logs3" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/logs-migration/status" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/migration-status" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/migration-version" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/otel/v1/traces" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_method, {
          consumes = ["application/json", "application/x-protobuf"]
        })
      }
      "/ping" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/proxy-url" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/realtime-url" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/v1" = {
        for method in ["get", "options"] : method => local.snippet_api_json_method
      }
      "/v1/function" = {
        for method in ["get", "options", "post", "put"] : method => local.snippet_api_json_method
      }
      "/v1/function/{id}" = {
        for method in ["delete", "get", "options", "patch"] : method => merge(local.snippet_api_json_method, {
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/v1/insert" = {
        for method in ["options", "post"] : method => local.snippet_api_json_method
      }
      "/v1/prompt" = {
        for method in ["get", "options", "post", "put"] : method => local.snippet_api_json_method
      }
      "/v1/prompt/{id}" = {
        for method in ["delete", "get", "options", "patch"] : method => merge(local.snippet_api_json_method, {
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/v1/{object_type}" = {
        for method in ["get", "options", "post", "put"] : method => merge(local.snippet_api_json_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/v1/{object_type}/{id}" = {
        for method in ["delete", "get", "options", "patch", "post"] : method => merge(local.snippet_api_json_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/v1/{object_type}/{id}/feedback" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/v1/{object_type}/{id}/fetch" = {
        for method in ["get", "options", "post"] : method => merge(local.snippet_api_json_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/v1/{object_type}/{id}/insert" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/v1/{object_type}/{id}/summarize" = {
        for method in ["get", "options"] : method => merge(local.snippet_api_json_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/environment" = {
        for method in ["get", "options", "post"] : method => local.snippet_api_json_text_method
      }
      "/environment/{id}" = {
        for method in ["delete", "get", "options", "patch"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/environment-object/{object_type}/{object_id}" = {
        for method in ["get", "options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "object_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/environment-object/{object_type}/{object_id}/{environment_slug}" = {
        for method in ["delete", "get", "options", "put"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_type"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "object_id"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "environment_slug"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/version" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/version-0.0.54" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/xact-id" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/test-automation" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/service-token/upsert" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/service-token/{name}" = {
        for method in ["options", "head", "get"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "name"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/brainstore/version" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/status" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/backfill/status/active" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/backfill/status/failed" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/vacuum/status" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/vacuum/reset_state" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/vacuum/object/{object_id}" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/brainstore/vacuum/index/object/{object_id}" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/brainstore/vacuum/segment_wal/object/{object_id}" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/automation/flush-cache" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/automation/cloud-identity" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/automation/cron" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/automation/cron/{id}/status" = {
        for method in ["get", "options"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/automation/cron/{id}/run" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/automation/cron/{id}/reset" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/billing/status" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/billing/refresh" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/time_based_retention/status" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/time_based_retention/reset_state" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/brainstore/time_based_retention/object/{object_id}" = {
        for method in ["options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "object_id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/brainstore/time_based_retention" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/.well-known/{resource}" = {
        for method in ["get", "options"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "resource"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/.well-known/{resource}/{subresource}" = {
        for method in ["get", "options"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "resource"
              in       = "path"
              required = true
              type     = "string"
            },
            {
              name     = "subresource"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/oauth/{command}" = {
        for method in ["get", "options", "post"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "command"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/mcp" = {
        for method in ["get", "options", "post"] : method => local.snippet_api_json_text_method
      }
      "/register" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/authorize" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/token" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/sse" = {
        for method in ["get", "options"] : method => local.snippet_api_json_text_method
      }
      "/deep-search" = {
        for method in ["get", "options", "post"] : method => local.snippet_api_json_text_method
      }
      "/deep-search/{id}" = {
        for method in ["get", "options", "patch", "delete"] : method => merge(local.snippet_api_json_text_method, {
          parameters = [
            {
              name     = "id"
              in       = "path"
              required = true
              type     = "string"
            }
          ]
        })
      }
      "/mcp-client/well-known" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/mcp-client/token" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/mcp-client/proxy" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
      "/mcp-client/oauth-register" = {
        for method in ["options", "post"] : method => local.snippet_api_json_text_method
      }
    }

    x-amazon-apigateway-binary-media-types = [
      "*/*",
      "application/json",
      "application/octet-stream",
      "application/x-tar",
      "application/zip",
      "audio/basic",
      "audio/ogg",
      "audio/mp4",
      "audio/mpeg",
      "audio/wav",
      "audio/webm",
      "image/png",
      "image/jpg",
      "image/jpeg",
      "image/gif",
      "video/ogg",
      "video/mpeg",
      "video/webm"
    ]
  }
}
