locals {
  api_version_tag       = var.api_version_override != null ? var.api_version_override : jsondecode(file("${path.module}/VERSIONS.json"))["api"]
  observability_enabled = var.internal_observability_api_key_secret_arn != ""

  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  using_brainstore_writer      = var.brainstore_writer_hostname != null && var.brainstore_writer_hostname != ""
  using_brainstore_fast_reader = var.brainstore_fast_reader_hostname != null && var.brainstore_fast_reader_hostname != ""

  # When both an ACM certificate and a custom domain are provided, the ALB serves
  # HTTPS on 443 and the API URL points at the custom domain so the certificate
  # validates. Otherwise the ALB serves plain HTTP on 80 via its AWS DNS name.
  alb_https_enabled        = var.alb_certificate_arn != null && var.alb_custom_domain != null
  alb_listener_port        = local.alb_https_enabled ? 443 : 80
  api_ecs_url              = local.alb_https_enabled ? "https://${var.alb_custom_domain}" : "http://${aws_lb.api_ecs.dns_name}"
  unsafe_url_request_mode  = var.unsafe_url_request_mode == null ? "" : trimspace(var.unsafe_url_request_mode)
  url_security_dns_servers = var.url_security_dns_servers == null ? "" : trimspace(var.url_security_dns_servers)
  url_security_allow_cidrs = var.url_security_allow_cidrs == null ? "" : trimspace(var.url_security_allow_cidrs)
  url_security_env_vars = merge(
    local.unsafe_url_request_mode != "" ? {
      BRAINTRUST_UNSAFE_URL_REQUEST_MODE = local.unsafe_url_request_mode
    } : {},
    local.url_security_dns_servers != "" ? {
      BRAINTRUST_URL_SECURITY_DNS_SERVERS = local.url_security_dns_servers
    } : {},
    local.url_security_allow_cidrs != "" ? {
      BRAINTRUST_URL_SECURITY_ALLOW_CIDRS = local.url_security_allow_cidrs
    } : {}
  )

  base_env_vars = merge({
    ORG_NAME                                          = var.braintrust_org_name
    PRIMARY_ORG_NAME                                  = var.primary_org_name
    ALLOWED_ORG_IDS                                   = var.allowed_org_ids
    BRAINTRUST_DEPLOYMENT_NAME                        = var.deployment_name
    BRAINTRUST_LEGACY_IDS                             = "true" # emit v3 spans in py+ts sdks. remove this setting when v4 migration is complete
    RESPONSE_BUCKET                                   = var.response_bucket
    CODE_BUNDLE_BUCKET                                = var.code_bundle_bucket
    WHITELISTED_ORIGINS                               = join(",", var.whitelisted_origins)
    OUTBOUND_RATE_LIMIT_WINDOW_MINUTES                = tostring(var.outbound_rate_limit_window_minutes)
    OUTBOUND_RATE_LIMIT_MAX_REQUESTS                  = tostring(var.outbound_rate_limit_max_requests)
    QUARANTINE_INVOKE_ROLE                            = var.use_quarantine_vpc && var.quarantine_invoke_role_arn != null ? var.quarantine_invoke_role_arn : ""
    QUARANTINE_FUNCTION_ROLE                          = var.use_quarantine_vpc && var.quarantine_function_role_arn != null ? var.quarantine_function_role_arn : ""
    QUARANTINE_PROXY_URL                              = var.quarantine_proxy_url
    QUARANTINE_PRIVATE_SUBNET_1_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[0] : ""
    QUARANTINE_PRIVATE_SUBNET_2_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[1] : ""
    QUARANTINE_PRIVATE_SUBNET_3_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[2] : ""
    QUARANTINE_PUB_PRIVATE_VPC_DEFAULT_SECURITY_GROUP = var.use_quarantine_vpc && var.quarantine_lambda_security_group_id != null ? var.quarantine_lambda_security_group_id : ""
    QUARANTINE_PUB_PRIVATE_VPC_ID                     = var.use_quarantine_vpc ? var.quarantine_vpc_id : ""
    BRAINSTORE_ENABLED                                = "true"
    BRAINSTORE_DEFAULT                                = "force"
    BRAINSTORE_URL                                    = "http://${var.brainstore_hostname}:${var.brainstore_port}"
    BRAINSTORE_WRITER_URL                             = local.using_brainstore_writer ? "http://${var.brainstore_writer_hostname}:${var.brainstore_port}" : ""
    BRAINSTORE_REALTIME_WAL_BUCKET                    = var.brainstore_s3_bucket_name != null ? var.brainstore_s3_bucket_name : ""
    BRAINSTORE_INSERT_ROW_REFS                        = "true"
    CONTROL_PLANE_TELEMETRY                           = var.monitoring_telemetry
    TELEMETRY_DISABLE_AGGREGATION                     = tostring(var.disable_billing_telemetry_aggregation)
    TELEMETRY_LOG_LEVEL                               = var.billing_telemetry_log_level
    INSERT_LOGS2                                      = "true"
    NODE_MEMORY_PERCENT                               = "80"
    AI_PROXY_FN_URL                                   = "http://127.0.0.1:8000"
    BRAINSTORE_DISABLE_ETL_LOOP                       = "true"
    DISABLE_ASYNC_SCORING                             = "false"
    DISABLE_ATTACHMENT_OPTIMIZATION                   = "false"
    ENABLE_DEEP_SEARCH_LOGGING                        = "false"
    ENABLE_CLOUDWATCH_METRICS                         = "true"
    ENABLE_RUNTIME_METRICS                            = "false"
    AUTOMATION_CRON_MAX_CONCURRENCY                   = "0"
    DISABLE_LOCAL_BACKGROUND_LOOPS                    = "true"
    TS_API_HOST                                       = "0.0.0.0"
    TS_API_PORT                                       = "8000"
    PROXY_URL                                         = "http://127.0.0.1:8000/v1/proxy"
    TS_API_ASYNC_SCORING_PROXY_URL                    = "http://127.0.0.1:8000"
    },
    local.url_security_env_vars,
    local.using_brainstore_fast_reader ? {
      BRAINSTORE_FAST_READER_URL           = "http://${var.brainstore_fast_reader_hostname}:${var.brainstore_port}"
      BRAINSTORE_FAST_READER_QUERY_SOURCES = "summaryPaginatedObjectViewer [realtime],summaryPaginatedObjectViewer,a602c972-1843-4ee1-b6bc-d3c1075cd7e7,traceQueryFn-id,traceQueryFn-rootSpanId,fullSpanQueryFn-root_span_id,fullSpanQueryFn-id"
    } : {},
    var.brainstore_wal_footer_version != "" ? {
      BRAINSTORE_WAL_FOOTER_VERSION = var.brainstore_wal_footer_version
    } : {},
    var.skip_pg_for_brainstore_objects != "" ? {
      SKIP_PG_FOR_BRAINSTORE_OBJECTS = var.skip_pg_for_brainstore_objects
    } : {},
    (var.brainstore_wal_footer_version != "" || var.skip_pg_for_brainstore_objects != "") ? {
      BRAINSTORE_WAL_USE_EFFICIENT_FORMAT = "true"
    } : {},
    var.brainstore_enable_export ? {
      BRAINSTORE_EXPORT_MIGRATION_ENABLED = "true"
    } : {},
    var.brainstore_etl_batch_size != null ? {
      BRAINSTORE_BACKFILL_HISTORICAL_BATCH_SIZE = tostring(var.brainstore_etl_batch_size)
    } : {},
    local.observability_enabled && trimspace(var.internal_observability_trace_disabled_plugins) != "" ? {
      DD_TRACE_DISABLED_PLUGINS = var.internal_observability_trace_disabled_plugins
    } : {},
  )

  merged_env_vars = merge(local.base_env_vars, var.extra_env_vars)

  api_service_names = ["braintrust-api", "braintrust-api-ingest", "braintrust-api-background"]

  api_log_group_names = {
    "braintrust-api"            = aws_cloudwatch_log_group.braintrust_api.name
    "braintrust-api-ingest"     = aws_cloudwatch_log_group.braintrust_api_ingest.name
    "braintrust-api-background" = aws_cloudwatch_log_group.braintrust_api_background.name
  }

  api_service_env_vars = {
    for service_name in local.api_service_names :
    service_name => merge(local.merged_env_vars, {
      CLOUDWATCH_METRICS_SERVICE_NAME    = service_name
      CLOUDWATCH_METRICS_DEPLOYMENT_NAME = var.deployment_name
    })
  }

  legacy_api_env_vars = merge(local.merged_env_vars, {
    CLOUDWATCH_METRICS_SERVICE_NAME    = "api-ecs"
    CLOUDWATCH_METRICS_DEPLOYMENT_NAME = var.deployment_name
  })

  api_container_depends_on = [
    for dep in [
      {
        containerName = "log-router"
        condition     = "START"
      },
      {
        containerName = "datadog-agent"
        condition     = "START"
      }
    ] : dep if local.observability_enabled
  ]

  api_container_base = {
    name      = "api"
    image     = "${var.container_image_repository}:${local.api_version_tag}"
    essential = true
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [
      {
        containerPort = 8000
        hostPort      = 8000
        protocol      = "tcp"
      }
    ]
    secrets = [
      {
        name      = "FUNCTION_SECRET_KEY"
        valueFrom = var.function_tools_secret_arn
      },
      {
        name      = "PG_URL"
        valueFrom = var.database_url_secret_arn
      },
      {
        name      = "REDIS_URL"
        valueFrom = var.redis_url_secret_arn
      },
      {
        name      = "SERVICE_TOKEN_SECRET_KEY"
        valueFrom = var.function_tools_secret_arn
      }
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8000/ || exit 1"]
      interval    = 30
      retries     = 3
      startPeriod = 10
      timeout     = 5
    }
    mountPoints    = []
    systemControls = []
    volumesFrom    = []
  }

  api_log_configurations = {
    for service_name in local.api_service_names :
    service_name => jsondecode(local.observability_enabled ? jsonencode({
      logDriver = "awsfirelens"
      options = {
        Name           = "datadog"
        Host           = "http-intake.logs.${var.internal_observability_region}.datadoghq.com"
        TLS            = "on"
        provider       = "ecs"
        dd_service     = service_name
        dd_source      = "nodejs"
        dd_message_key = "msg"
        dd_tags        = "env:${var.internal_observability_env_name}"
        compress       = "gzip"
      }
      secretOptions = [
        {
          name      = "apikey"
          valueFrom = var.internal_observability_api_key_secret_arn
        }
      ]
      }) : jsonencode({
      logDriver = "awslogs"
      options = {
        awslogs-group         = local.api_log_group_names[service_name]
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = service_name
      }
    }))
  }

  observability_log_groups = local.api_log_group_names

  observability_sidecars = {
    for service_name in local.api_service_names :
    service_name => [
      for sidecar in [
        {
          name           = "log-router"
          essential      = true
          image          = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
          user           = "0"
          environment    = []
          mountPoints    = []
          portMappings   = []
          systemControls = []
          volumesFrom    = []
          firelensConfiguration = {
            type = "fluentbit"
            options = {
              enable-ecs-log-metadata = "true"
              config-file-type        = "file"
              config-file-value       = "/fluent-bit/configs/parse-json.conf"
            }
          }
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = local.observability_log_groups[service_name]
              awslogs-region        = data.aws_region.current.region
              awslogs-stream-prefix = "log-router"
            }
          }
          memoryReservation = 50
        },
        {
          name           = "datadog-agent"
          essential      = true
          image          = "public.ecr.aws/datadog/agent:7"
          mountPoints    = []
          portMappings   = []
          systemControls = []
          volumesFrom    = []
          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = local.observability_log_groups[service_name]
              awslogs-region        = data.aws_region.current.region
              awslogs-stream-prefix = "datadog-agent"
            }
          }
          environment = [
            {
              name  = "ECS_FARGATE"
              value = "true"
            },
            {
              name  = "DD_SITE"
              value = "${var.internal_observability_region}.datadoghq.com"
            },
            {
              name  = "DD_ENV"
              value = var.internal_observability_env_name
            },
            {
              name  = "DD_SERVICE"
              value = service_name
            },
            {
              name  = "DD_VERSION"
              value = local.api_version_tag
            },
            {
              name  = "DD_PROCESS_AGENT_ENABLED"
              value = "true"
            },
            {
              name  = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT"
              value = "0.0.0.0:4318"
            }
          ]
          secrets = [
            {
              name      = "DD_API_KEY"
              valueFrom = var.internal_observability_api_key_secret_arn
            }
          ]
          healthCheck = {
            command     = ["CMD-SHELL", "agent health"]
            interval    = 30
            retries     = 3
            startPeriod = 15
            timeout     = 5
          }
        }
      ] : sidecar if local.observability_enabled
    ]
  }

  api_container_definitions = {
    for service_name in local.api_service_names :
    service_name => jsonencode(concat([
      merge(local.api_container_base, {
        dependsOn        = local.api_container_depends_on
        logConfiguration = local.api_log_configurations[service_name]
        environment = [
          for key in sort(keys(local.api_service_env_vars[service_name])) : {
            name  = key
            value = local.api_service_env_vars[service_name][key]
          }
        ]
      })
    ], local.observability_sidecars[service_name]))
  }

  valid_fargate_memory_by_cpu = {
    "256"   = [512, 1024, 2048]
    "512"   = [1024, 2048, 3072, 4096]
    "1024"  = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
    "2048"  = [for value in range(4096, 16385, 1024) : value]
    "4096"  = [for value in range(8192, 30721, 1024) : value]
    "8192"  = [for value in range(16384, 61441, 4096) : value]
    "16384" = [for value in range(32768, 122881, 8192) : value]
  }
}

data "aws_region" "current" {}
