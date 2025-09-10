<!-- BEGIN_TF_DOCS -->
## Required Inputs

The following input variables are required:

### <a name="input_braintrust_org_name"></a> [braintrust\_org\_name](#input\_braintrust\_org\_name)

Description: The name of your organization in Braintrust (e.g. acme.com)

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_additional_kms_key_policies"></a> [additional\_kms\_key\_policies](#input\_additional\_kms\_key\_policies)

Description: Additional IAM policy statements to append to the generated KMS key.

Type: `list(any)`

Default: `[]`

### <a name="input_ai_proxy_reserved_concurrent_executions"></a> [ai\_proxy\_reserved\_concurrent\_executions](#input\_ai\_proxy\_reserved\_concurrent\_executions)

Description: The number of concurrent executions to reserve for the AI Proxy. Setting this will prevent the AI Proxy from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account.

Type: `number`

Default: `-1`

### <a name="input_api_handler_provisioned_concurrency"></a> [api\_handler\_provisioned\_concurrency](#input\_api\_handler\_provisioned\_concurrency)

Description: The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost.

Type: `number`

Default: `1`

### <a name="input_api_handler_reserved_concurrent_executions"></a> [api\_handler\_reserved\_concurrent\_executions](#input\_api\_handler\_reserved\_concurrent\_executions)

Description: The number of concurrent executions to reserve for the API Handler. Setting this will prevent the API Handler from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account.

Type: `number`

Default: `-1`

### <a name="input_billing_telemetry_log_level"></a> [billing\_telemetry\_log\_level](#input\_billing\_telemetry\_log\_level)

Description: Log level for billing telemetry. Defaults to 'error' if empty, or unspecified.

Type: `string`

Default: `""`

### <a name="input_brainstore_backfill_new_objects"></a> [brainstore\_backfill\_new\_objects](#input\_brainstore\_backfill\_new\_objects)

Description: Enable backfill for new objects for Brainstore. Don't modify this unless instructed by Braintrust.

Type: `bool`

Default: `true`

### <a name="input_brainstore_default"></a> [brainstore\_default](#input\_brainstore\_default)

Description: Whether to set Brainstore as the default rather than requiring users to opt-in via feature flag. Don't set this if you have a large backfill ongoing and are migrating from Clickhouse.

Type: `string`

Default: `"force"`

### <a name="input_brainstore_enable_historical_full_backfill"></a> [brainstore\_enable\_historical\_full\_backfill](#input\_brainstore\_enable\_historical\_full\_backfill)

Description: Enable historical full backfill for Brainstore. Don't modify this unless instructed by Braintrust.

Type: `bool`

Default: `true`

### <a name="input_brainstore_etl_batch_size"></a> [brainstore\_etl\_batch\_size](#input\_brainstore\_etl\_batch\_size)

Description: The batch size for the ETL process

Type: `number`

Default: `null`

### <a name="input_brainstore_extra_env_vars"></a> [brainstore\_extra\_env\_vars](#input\_brainstore\_extra\_env\_vars)

Description: Extra environment variables to set for Brainstore reader or dual use nodes

Type: `map(string)`

Default: `{}`

### <a name="input_brainstore_extra_env_vars_writer"></a> [brainstore\_extra\_env\_vars\_writer](#input\_brainstore\_extra\_env\_vars\_writer)

Description: Extra environment variables to set for Brainstore writer nodes

Type: `map(string)`

Default: `{}`

### <a name="input_brainstore_instance_count"></a> [brainstore\_instance\_count](#input\_brainstore\_instance\_count)

Description: The number of Brainstore reader instances to provision

Type: `number`

Default: `2`

### <a name="input_brainstore_instance_key_pair_name"></a> [brainstore\_instance\_key\_pair\_name](#input\_brainstore\_instance\_key\_pair\_name)

Description: The name of the key pair to use for the Brainstore instance

Type: `string`

Default: `null`

### <a name="input_brainstore_instance_type"></a> [brainstore\_instance\_type](#input\_brainstore\_instance\_type)

Description: The instance type to use for Brainstore reader nodes. Recommended Graviton instance type with 16GB of memory and a local SSD for cache data.

Type: `string`

Default: `"c8gd.4xlarge"`

### <a name="input_brainstore_license_key"></a> [brainstore\_license\_key](#input\_brainstore\_license\_key)

Description: The license key for the Brainstore instance

Type: `string`

Default: `null`

### <a name="input_brainstore_port"></a> [brainstore\_port](#input\_brainstore\_port)

Description: The port to use for the Brainstore instance

Type: `number`

Default: `4000`

### <a name="input_brainstore_s3_bucket_retention_days"></a> [brainstore\_s3\_bucket\_retention\_days](#input\_brainstore\_s3\_bucket\_retention\_days)

Description: The number of days to retain non-current S3 objects. e.g. deleted objects

Type: `number`

Default: `7`

### <a name="input_brainstore_enable_retention"></a> [brainstore\_enable\_retention](#input\_brainstore\_enable\_retention)

Description: Enable time-based retention for Brainstore

Type: `boolnumber`

Default: `false`

### <a name="input_brainstore_version_override"></a> [brainstore\_version\_override](#input\_brainstore\_version\_override)

Description: Lock Brainstore on a specific version. Don't set this unless instructed by Braintrust.

Type: `string`

Default: `null`

### <a name="input_brainstore_writer_instance_count"></a> [brainstore\_writer\_instance\_count](#input\_brainstore\_writer\_instance\_count)

Description: The number of dedicated writer nodes to create

Type: `number`

Default: `1`

### <a name="input_brainstore_writer_instance_type"></a> [brainstore\_writer\_instance\_type](#input\_brainstore\_writer\_instance\_type)

Description: The instance type to use for the Brainstore writer nodes

Type: `string`

Default: `"c8gd.8xlarge"`

### <a name="input_clickhouse_instance_type"></a> [clickhouse\_instance\_type](#input\_clickhouse\_instance\_type)

Description: The instance type to use for the Clickhouse instance

Type: `string`

Default: `"c5.2xlarge"`

### <a name="input_clickhouse_metadata_storage_size"></a> [clickhouse\_metadata\_storage\_size](#input\_clickhouse\_metadata\_storage\_size)

Description: The size of the EBS volume to use for Clickhouse metadata

Type: `number`

Default: `100`

### <a name="input_custom_certificate_arn"></a> [custom\_certificate\_arn](#input\_custom\_certificate\_arn)

Description: ARN of the ACM certificate for the custom domain

Type: `string`

Default: `null`

### <a name="input_custom_domain"></a> [custom\_domain](#input\_custom\_domain)

Description: Custom domain name for the CloudFront distribution

Type: `string`

Default: `null`

### <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name)

Description: Name of this Braintrust deployment. Will be included in tags and prefixes in resources names. Lowercase letter, numbers, and hyphens only. If you want multiple deployments in your same AWS account, use a unique name for each deployment.

Type: `string`

Default: `"braintrust"`

### <a name="input_disable_billing_telemetry_aggregation"></a> [disable\_billing\_telemetry\_aggregation](#input\_disable\_billing\_telemetry\_aggregation)

Description: Disable billing telemetry aggregation. Do not disable this unless instructed by support.

Type: `bool`

Default: `false`

### <a name="input_enable_brainstore"></a> [enable\_brainstore](#input\_enable\_brainstore)

Description: Enable Brainstore for faster analytics

Type: `bool`

Default: `true`

### <a name="input_enable_braintrust_support_logs_access"></a> [enable\_braintrust\_support\_logs\_access](#input\_enable\_braintrust\_support\_logs\_access)

Description: Enable Cloudwatch logs access for Braintrust staff

Type: `bool`

Default: `false`

### <a name="input_enable_braintrust_support_shell_access"></a> [enable\_braintrust\_support\_shell\_access](#input\_enable\_braintrust\_support\_shell\_access)

Description: Enable Bastion shell access for Braintrust staff. This will create a bastion host and a security group that allows EC2 instance connect access from the Braintrust IAM Role.

Type: `bool`

Default: `false`

### <a name="input_enable_clickhouse"></a> [enable\_clickhouse](#input\_enable\_clickhouse)

Description: Enable Clickhouse for faster analytics

Type: `bool`

Default: `false`

### <a name="input_enable_quarantine_vpc"></a> [enable\_quarantine\_vpc](#input\_enable\_quarantine\_vpc)

Description: Enable the Quarantine VPC to run user defined functions in an isolated environment. If disabled, user defined functions will not be available.

Type: `bool`

Default: `true`

### <a name="input_internal_observability_api_key"></a> [internal\_observability\_api\_key](#input\_internal\_observability\_api\_key)

Description: Support for internal observability agent. Do not set this unless instructed by support.

Type: `string`

Default: `""`

### <a name="input_internal_observability_env_name"></a> [internal\_observability\_env\_name](#input\_internal\_observability\_env\_name)

Description: Support for internal observability agent. Do not set this unless instructed by support.

Type: `string`

Default: `""`

### <a name="input_internal_observability_region"></a> [internal\_observability\_region](#input\_internal\_observability\_region)

Description: Support for internal observability agent. Do not set this unless instructed by support.

Type: `string`

Default: `"us5"`

### <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn)

Description: Existing KMS key ARN to use for encrypting resources. If not provided, a new key will be created. DO NOT change this after deployment. If you do, it will attempt to destroy your DB and prior S3 objects will no longer be readable.

Type: `string`

Default: `""`

### <a name="input_lambda_version_tag_override"></a> [lambda\_version\_tag\_override](#input\_lambda\_version\_tag\_override)

Description: Optional override for the lambda version tag. Don't set this unless instructed by Braintrust.

Type: `string`

Default: `null`

### <a name="input_monitoring_telemetry"></a> [monitoring\_telemetry](#input\_monitoring\_telemetry)

Description: The telemetry to send to Braintrust's control plane to monitor your deployment. Should be in the form of comma-separated values.

Available options:
- status: Health check information (default)
- metrics: System metrics (CPU/memory) and Braintrust-specific metrics like indexing lag (default)
- usage: Billing usage telemetry for aggregate usage metrics
- memprof: Memory profiling statistics and heap usage patterns
- logs: Application logs
- traces: Distributed tracing data

Type: `string`

Default: `"status,metrics,usage"`

### <a name="input_outbound_rate_limit_max_requests"></a> [outbound\_rate\_limit\_max\_requests](#input\_outbound\_rate\_limit\_max\_requests)

Description: The maximum number of requests per user allowed in the time frame specified by OutboundRateLimitMaxRequests. Setting to 0 will disable rate limits

Type: `number`

Default: `0`

### <a name="input_outbound_rate_limit_window_minutes"></a> [outbound\_rate\_limit\_window\_minutes](#input\_outbound\_rate\_limit\_window\_minutes)

Description: The time frame in minutes over which rate per-user rate limits are accumulated

Type: `number`

Default: `1`

### <a name="input_postgres_auto_minor_version_upgrade"></a> [postgres\_auto\_minor\_version\_upgrade](#input\_postgres\_auto\_minor\_version\_upgrade)

Description: Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window. When true you will have to set your postgres\_version to only the major number or you will see drift. e.g. '15' instead of '15.7'

Type: `bool`

Default: `true`

### <a name="input_postgres_instance_type"></a> [postgres\_instance\_type](#input\_postgres\_instance\_type)

Description: Instance type for the RDS instance.

Type: `string`

Default: `"db.r8g.2xlarge"`

### <a name="input_postgres_max_storage_size"></a> [postgres\_max\_storage\_size](#input\_postgres\_max\_storage\_size)

Description: Maximum storage size (in GB) to allow the RDS instance to auto-scale to.

Type: `number`

Default: `4000`

### <a name="input_postgres_multi_az"></a> [postgres\_multi\_az](#input\_postgres\_multi\_az)

Description: Specifies if the RDS instance is multi-AZ. Increases cost but provides higher availability. Recommended for production environments.

Type: `bool`

Default: `false`

### <a name="input_postgres_storage_iops"></a> [postgres\_storage\_iops](#input\_postgres\_storage\_iops)

Description: Storage IOPS for the RDS instance. Only applicable if storage\_type is io1, io2, or gp3.

Type: `number`

Default: `10000`

### <a name="input_postgres_storage_size"></a> [postgres\_storage\_size](#input\_postgres\_storage\_size)

Description: Storage size (in GB) for the RDS instance.

Type: `number`

Default: `1000`

### <a name="input_postgres_storage_throughput"></a> [postgres\_storage\_throughput](#input\_postgres\_storage\_throughput)

Description: Throughput for the RDS instance. Only applicable if storage\_type is gp3.

Type: `number`

Default: `500`

### <a name="input_postgres_storage_type"></a> [postgres\_storage\_type](#input\_postgres\_storage\_type)

Description: Storage type for the RDS instance.

Type: `string`

Default: `"gp3"`

### <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version)

Description: PostgreSQL engine version for the RDS instance.

Type: `string`

Default: `"15"`

### <a name="input_private_subnet_1_az"></a> [private\_subnet\_1\_az](#input\_private\_subnet\_1\_az)

Description: Availability zone for the first private subnet. Leave blank to choose the first available zone

Type: `string`

Default: `null`

### <a name="input_private_subnet_2_az"></a> [private\_subnet\_2\_az](#input\_private\_subnet\_2\_az)

Description: Availability zone for the first private subnet. Leave blank to choose the second available zone

Type: `string`

Default: `null`

### <a name="input_private_subnet_3_az"></a> [private\_subnet\_3\_az](#input\_private\_subnet\_3\_az)

Description: Availability zone for the third private subnet. Leave blank to choose the third available zone

Type: `string`

Default: `null`

### <a name="input_public_subnet_1_az"></a> [public\_subnet\_1\_az](#input\_public\_subnet\_1\_az)

Description: Availability zone for the public subnet. Leave blank to choose the first available zone

Type: `string`

Default: `null`

### <a name="input_quarantine_private_subnet_1_az"></a> [quarantine\_private\_subnet\_1\_az](#input\_quarantine\_private\_subnet\_1\_az)

Description: Availability zone for the first private subnet. Leave blank to choose the first available zone

Type: `string`

Default: `null`

### <a name="input_quarantine_private_subnet_2_az"></a> [quarantine\_private\_subnet\_2\_az](#input\_quarantine\_private\_subnet\_2\_az)

Description: Availability zone for the first private subnet. Leave blank to choose the second available zone

Type: `string`

Default: `null`

### <a name="input_quarantine_private_subnet_3_az"></a> [quarantine\_private\_subnet\_3\_az](#input\_quarantine\_private\_subnet\_3\_az)

Description: Availability zone for the third private subnet. Leave blank to choose the third available zone

Type: `string`

Default: `null`

### <a name="input_quarantine_public_subnet_1_az"></a> [quarantine\_public\_subnet\_1\_az](#input\_quarantine\_public\_subnet\_1\_az)

Description: Availability zone for the public subnet. Leave blank to choose the first available zone

Type: `string`

Default: `null`

### <a name="input_quarantine_vpc_cidr"></a> [quarantine\_vpc\_cidr](#input\_quarantine\_vpc\_cidr)

Description: CIDR block for the Quarantined VPC

Type: `string`

Default: `"10.175.8.0/21"`

### <a name="input_redis_instance_type"></a> [redis\_instance\_type](#input\_redis\_instance\_type)

Description: Instance type for the Redis cluster

Type: `string`

Default: `"cache.t4g.medium"`

### <a name="input_redis_version"></a> [redis\_version](#input\_redis\_version)

Description: Redis engine version

Type: `string`

Default: `"7.0"`

### <a name="input_s3_additional_allowed_origins"></a> [s3\_additional\_allowed\_origins](#input\_s3\_additional\_allowed\_origins)

Description: Additional origins to allow for S3 bucket CORS configuration. Supports a wildcard in the domain name.

Type: `list(string)`

Default: `[]`

### <a name="input_service_additional_policy_arns"></a> [service\_additional\_policy\_arns](#input\_service\_additional\_policy\_arns)

Description: Additional policy ARNs to attach to the lambda functions that are the main braintrust service

Type: `list(string)`

Default: `[]`

### <a name="input_service_extra_env_vars"></a> [service\_extra\_env\_vars](#input\_service\_extra\_env\_vars)

Description: Extra environment variables to set for services

Type:

```hcl
object({
    APIHandler               = map(string)
    AIProxy                  = map(string)
    CatchupETL               = map(string)
    BillingCron              = map(string)
    MigrateDatabaseFunction  = map(string)
    QuarantineWarmupFunction = map(string)
    AutomationCron           = map(string)
  })
```

Default:

```json
{
  "AIProxy": {},
  "APIHandler": {},
  "AutomationCron": {},
  "BillingCron": {},
  "CatchupETL": {},
  "MigrateDatabaseFunction": {},
  "QuarantineWarmupFunction": {}
}
```

### <a name="input_use_external_clickhouse_address"></a> [use\_external\_clickhouse\_address](#input\_use\_external\_clickhouse\_address)

Description: Do not change this unless instructed by Braintrust. If set, the domain name or IP of the external Clickhouse instance will be used and no internal instance will be created.

Type: `string`

Default: `null`

### <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr)

Description: CIDR block for the VPC

Type: `string`

Default: `"10.175.0.0/21"`

### <a name="input_whitelisted_origins"></a> [whitelisted\_origins](#input\_whitelisted\_origins)

Description: List of origins to whitelist for CORS

Type: `list(string)`

Default: `[]`

## Outputs

The following outputs are exported:

### <a name="output_api_url"></a> [api\_url](#output\_api\_url)

Description: The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL.

### <a name="output_bastion_instance_id"></a> [bastion\_instance\_id](#output\_bastion\_instance\_id)

Description: Instance ID of the bastion host that Braintrust support staff can connect to using EC2 Instance Connect. Share this with the Braintrust team.

### <a name="output_brainstore_s3_bucket_name"></a> [brainstore\_s3\_bucket\_name](#output\_brainstore\_s3\_bucket\_name)

Description: Name of the Brainstore S3 bucket

### <a name="output_brainstore_security_group_id"></a> [brainstore\_security\_group\_id](#output\_brainstore\_security\_group\_id)

Description: ID of the security group for the Brainstore instances

### <a name="output_braintrust_support_role_arn"></a> [braintrust\_support\_role\_arn](#output\_braintrust\_support\_role\_arn)

Description: ARN of the Role that grants Braintrust team remote support. Share this with the Braintrust team.

### <a name="output_clickhouse_host"></a> [clickhouse\_host](#output\_clickhouse\_host)

Description: Host of the Clickhouse instance

### <a name="output_clickhouse_s3_bucket_name"></a> [clickhouse\_s3\_bucket\_name](#output\_clickhouse\_s3\_bucket\_name)

Description: Name of the Clickhouse S3 bucket

### <a name="output_clickhouse_secret_id"></a> [clickhouse\_secret\_id](#output\_clickhouse\_secret\_id)

Description: ID of the Clickhouse secret. Note this is the Terraform ID attribute which is a pipe delimited combination of secret ID and version ID

### <a name="output_lambda_security_group_id"></a> [lambda\_security\_group\_id](#output\_lambda\_security\_group\_id)

Description: ID of the security group for the Lambda functions

### <a name="output_main_vpc_cidr"></a> [main\_vpc\_cidr](#output\_main\_vpc\_cidr)

Description: CIDR block of the main VPC

### <a name="output_main_vpc_id"></a> [main\_vpc\_id](#output\_main\_vpc\_id)

Description: ID of the main VPC that contains the Braintrust resources

### <a name="output_main_vpc_private_route_table_id"></a> [main\_vpc\_private\_route\_table\_id](#output\_main\_vpc\_private\_route\_table\_id)

Description: ID of the private route table in the main VPC

### <a name="output_main_vpc_private_subnet_1_id"></a> [main\_vpc\_private\_subnet\_1\_id](#output\_main\_vpc\_private\_subnet\_1\_id)

Description: ID of the first private subnet in the main VPC

### <a name="output_main_vpc_private_subnet_2_id"></a> [main\_vpc\_private\_subnet\_2\_id](#output\_main\_vpc\_private\_subnet\_2\_id)

Description: ID of the second private subnet in the main VPC

### <a name="output_main_vpc_private_subnet_3_id"></a> [main\_vpc\_private\_subnet\_3\_id](#output\_main\_vpc\_private\_subnet\_3\_id)

Description: ID of the third private subnet in the main VPC

### <a name="output_main_vpc_public_route_table_id"></a> [main\_vpc\_public\_route\_table\_id](#output\_main\_vpc\_public\_route\_table\_id)

Description: ID of the public route table in the main VPC

### <a name="output_main_vpc_public_subnet_1_id"></a> [main\_vpc\_public\_subnet\_1\_id](#output\_main\_vpc\_public\_subnet\_1\_id)

Description: ID of the public subnet in the main VPC

### <a name="output_postgres_database_arn"></a> [postgres\_database\_arn](#output\_postgres\_database\_arn)

Description: ARN of the main Braintrust Postgres database

### <a name="output_quarantine_vpc_id"></a> [quarantine\_vpc\_id](#output\_quarantine\_vpc\_id)

Description: ID of the quarantine VPC that user functions run inside of.

### <a name="output_rds_security_group_id"></a> [rds\_security\_group\_id](#output\_rds\_security\_group\_id)

Description: ID of the security group for the RDS instance

### <a name="output_redis_arn"></a> [redis\_arn](#output\_redis\_arn)

Description: ARN of the Redis instance

### <a name="output_redis_security_group_id"></a> [redis\_security\_group\_id](#output\_redis\_security\_group\_id)

Description: ID of the security group for the Elasticache instance

### <a name="output_remote_support_security_group_id"></a> [remote\_support\_security\_group\_id](#output\_remote\_support\_security\_group\_id)

Description: Security Group ID for the Remote Support bastion host.
<!-- END_TF_DOCS -->
