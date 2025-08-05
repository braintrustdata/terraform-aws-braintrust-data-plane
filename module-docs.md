<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_kms\_key\_policies | Additional IAM policy statements to append to the generated KMS key. | `list(any)` | `[]` | no |
| ai\_proxy\_reserved\_concurrent\_executions | The number of concurrent executions to reserve for the AI Proxy. Setting this will prevent the AI Proxy from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account. | `number` | `-1` | no |
| api\_handler\_provisioned\_concurrency | The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost. | `number` | `1` | no |
| api\_handler\_reserved\_concurrent\_executions | The number of concurrent executions to reserve for the API Handler. Setting this will prevent the API Handler from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account. | `number` | `-1` | no |
| billing\_telemetry\_log\_level | Log level for billing telemetry. Defaults to 'error' if empty, or unspecified. | `string` | `""` | no |
| brainstore\_backfill\_new\_objects | Enable backfill for new objects for Brainstore. Don't modify this unless instructed by Braintrust. | `bool` | `true` | no |
| brainstore\_default | Whether to set Brainstore as the default rather than requiring users to opt-in via feature flag. Don't set this if you have a large backfill ongoing and are migrating from Clickhouse. | `string` | `"force"` | no |
| brainstore\_disable\_optimization\_worker | Disable the optimization worker globally in Brainstore | `bool` | `false` | no |
| brainstore\_enable\_historical\_full\_backfill | Enable historical full backfill for Brainstore. Don't modify this unless instructed by Braintrust. | `bool` | `true` | no |
| brainstore\_etl\_batch\_size | The batch size for the ETL process | `number` | `null` | no |
| brainstore\_extra\_env\_vars | Extra environment variables to set for Brainstore reader or dual use nodes | `map(string)` | `{}` | no |
| brainstore\_extra\_env\_vars\_writer | Extra environment variables to set for Brainstore writer nodes | `map(string)` | `{}` | no |
| brainstore\_instance\_count | The number of Brainstore reader instances to provision | `number` | `2` | no |
| brainstore\_instance\_key\_pair\_name | The name of the key pair to use for the Brainstore instance | `string` | `null` | no |
| brainstore\_instance\_type | The instance type to use for Brainstore reader nodes. Recommended Graviton instance type with 16GB of memory and a local SSD for cache data. | `string` | `"c8gd.4xlarge"` | no |
| brainstore\_license\_key | The license key for the Brainstore instance | `string` | `null` | no |
| brainstore\_port | The port to use for the Brainstore instance | `number` | `4000` | no |
| brainstore\_s3\_bucket\_retention\_days | The number of days to retain non-current S3 objects. e.g. deleted objects | `number` | `7` | no |
| brainstore\_vacuum\_all\_objects | Enable vacuuming of all objects in Brainstore | `bool` | `false` | no |
| brainstore\_version\_override | Lock Brainstore on a specific version. Don't set this unless instructed by Braintrust. | `string` | `null` | no |
| brainstore\_writer\_instance\_count | The number of dedicated writer nodes to create | `number` | `1` | no |
| brainstore\_writer\_instance\_type | The instance type to use for the Brainstore writer nodes | `string` | `"c8gd.8xlarge"` | no |
| braintrust\_org\_name | The name of your organization in Braintrust (e.g. acme.com) | `string` | n/a | yes |
| clickhouse\_instance\_type | The instance type to use for the Clickhouse instance | `string` | `"c5.2xlarge"` | no |
| clickhouse\_metadata\_storage\_size | The size of the EBS volume to use for Clickhouse metadata | `number` | `100` | no |
| custom\_certificate\_arn | ARN of the ACM certificate for the custom domain | `string` | `null` | no |
| custom\_domain | Custom domain name for the CloudFront distribution | `string` | `null` | no |
| deployment\_name | Name of this Braintrust deployment. Will be included in tags and prefixes in resources names. Lowercase letter, numbers, and hyphens only. If you want multiple deployments in your same AWS account, use a unique name for each deployment. | `string` | `"braintrust"` | no |
| disable\_billing\_telemetry\_aggregation | Disable billing telemetry aggregation. Do not disable this unless instructed by support. | `bool` | `false` | no |
| enable\_billing\_telemetry | Enable billing telemetry. Do not enable this unless instructed by support. | `bool` | `false` | no |
| enable\_brainstore | Enable Brainstore for faster analytics | `bool` | `true` | no |
| enable\_braintrust\_support\_logs\_access | Enable Cloudwatch logs access for Braintrust staff | `bool` | `false` | no |
| enable\_braintrust\_support\_shell\_access | Enable Bastion shell access for Braintrust staff. This will create a bastion host and a security group that allows EC2 instance connect access from the Braintrust IAM Role. | `bool` | `false` | no |
| enable\_clickhouse | Enable Clickhouse for faster analytics | `bool` | `false` | no |
| enable\_quarantine\_vpc | Enable the Quarantine VPC to run user defined functions in an isolated environment. If disabled, user defined functions will not be available. | `bool` | `true` | no |
| internal\_observability\_api\_key | Support for internal observability agent. Do not set this unless instructed by support. | `string` | `""` | no |
| internal\_observability\_env\_name | Support for internal observability agent. Do not set this unless instructed by support. | `string` | `""` | no |
| internal\_observability\_region | Support for internal observability agent. Do not set this unless instructed by support. | `string` | `"us5"` | no |
| kms\_key\_arn | Existing KMS key ARN to use for encrypting resources. If not provided, a new key will be created. DO NOT change this after deployment. If you do, it will attempt to destroy your DB and prior S3 objects will no longer be readable. | `string` | `""` | no |
| lambda\_version\_tag\_override | Optional override for the lambda version tag. Don't set this unless instructed by Braintrust. | `string` | `null` | no |
| outbound\_rate\_limit\_max\_requests | The maximum number of requests per user allowed in the time frame specified by OutboundRateLimitMaxRequests. Setting to 0 will disable rate limits | `number` | `0` | no |
| outbound\_rate\_limit\_window\_minutes | The time frame in minutes over which rate per-user rate limits are accumulated | `number` | `1` | no |
| postgres\_auto\_minor\_version\_upgrade | Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window. When true you will have to set your postgres\_version to only the major number or you will see drift. e.g. '15' instead of '15.7' | `bool` | `true` | no |
| postgres\_instance\_type | Instance type for the RDS instance. | `string` | `"db.r8g.2xlarge"` | no |
| postgres\_max\_storage\_size | Maximum storage size (in GB) to allow the RDS instance to auto-scale to. | `number` | `4000` | no |
| postgres\_multi\_az | Specifies if the RDS instance is multi-AZ. Increases cost but provides higher availability. Recommended for production environments. | `bool` | `false` | no |
| postgres\_storage\_iops | Storage IOPS for the RDS instance. Only applicable if storage\_type is io1, io2, or gp3. | `number` | `10000` | no |
| postgres\_storage\_size | Storage size (in GB) for the RDS instance. | `number` | `1000` | no |
| postgres\_storage\_throughput | Throughput for the RDS instance. Only applicable if storage\_type is gp3. | `number` | `500` | no |
| postgres\_storage\_type | Storage type for the RDS instance. | `string` | `"gp3"` | no |
| postgres\_version | PostgreSQL engine version for the RDS instance. | `string` | `"15"` | no |
| private\_subnet\_1\_az | Availability zone for the first private subnet. Leave blank to choose the first available zone | `string` | `null` | no |
| private\_subnet\_2\_az | Availability zone for the first private subnet. Leave blank to choose the second available zone | `string` | `null` | no |
| private\_subnet\_3\_az | Availability zone for the third private subnet. Leave blank to choose the third available zone | `string` | `null` | no |
| public\_subnet\_1\_az | Availability zone for the public subnet. Leave blank to choose the first available zone | `string` | `null` | no |
| quarantine\_private\_subnet\_1\_az | Availability zone for the first private subnet. Leave blank to choose the first available zone | `string` | `null` | no |
| quarantine\_private\_subnet\_2\_az | Availability zone for the first private subnet. Leave blank to choose the second available zone | `string` | `null` | no |
| quarantine\_private\_subnet\_3\_az | Availability zone for the third private subnet. Leave blank to choose the third available zone | `string` | `null` | no |
| quarantine\_public\_subnet\_1\_az | Availability zone for the public subnet. Leave blank to choose the first available zone | `string` | `null` | no |
| quarantine\_vpc\_cidr | CIDR block for the Quarantined VPC | `string` | `"10.175.8.0/21"` | no |
| redis\_instance\_type | Instance type for the Redis cluster | `string` | `"cache.t4g.medium"` | no |
| redis\_version | Redis engine version | `string` | `"7.0"` | no |
| s3\_additional\_allowed\_origins | Additional origins to allow for S3 bucket CORS configuration. Supports a wildcard in the domain name. | `list(string)` | `[]` | no |
| service\_additional\_policy\_arns | Additional policy ARNs to attach to the lambda functions that are the main braintrust service | `list(string)` | `[]` | no |
| service\_extra\_env\_vars | Extra environment variables to set for services | <pre>object({<br/>    APIHandler               = map(string)<br/>    AIProxy                  = map(string)<br/>    CatchupETL               = map(string)<br/>    BillingCron              = map(string)<br/>    MigrateDatabaseFunction  = map(string)<br/>    QuarantineWarmupFunction = map(string)<br/>    AutomationCron           = map(string)<br/>  })</pre> | <pre>{<br/>  "AIProxy": {},<br/>  "APIHandler": {},<br/>  "AutomationCron": {},<br/>  "BillingCron": {},<br/>  "CatchupETL": {},<br/>  "MigrateDatabaseFunction": {},<br/>  "QuarantineWarmupFunction": {}<br/>}</pre> | no |
| use\_external\_clickhouse\_address | Do not change this unless instructed by Braintrust. If set, the domain name or IP of the external Clickhouse instance will be used and no internal instance will be created. | `string` | `null` | no |
| vpc\_cidr | CIDR block for the VPC | `string` | `"10.175.0.0/21"` | no |
| whitelisted\_origins | List of origins to whitelist for CORS | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| api\_url | The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL. |
| bastion\_instance\_id | Instance ID of the bastion host that Braintrust support staff can connect to using EC2 Instance Connect. Share this with the Braintrust team. |
| brainstore\_s3\_bucket\_name | Name of the Brainstore S3 bucket |
| brainstore\_security\_group\_id | ID of the security group for the Brainstore instances |
| braintrust\_support\_role\_arn | ARN of the Role that grants Braintrust team remote support. Share this with the Braintrust team. |
| clickhouse\_host | Host of the Clickhouse instance |
| clickhouse\_s3\_bucket\_name | Name of the Clickhouse S3 bucket |
| clickhouse\_secret\_id | ID of the Clickhouse secret. Note this is the Terraform ID attribute which is a pipe delimited combination of secret ID and version ID |
| lambda\_security\_group\_id | ID of the security group for the Lambda functions |
| main\_vpc\_cidr | CIDR block of the main VPC |
| main\_vpc\_id | ID of the main VPC that contains the Braintrust resources |
| main\_vpc\_private\_route\_table\_id | ID of the private route table in the main VPC |
| main\_vpc\_private\_subnet\_1\_id | ID of the first private subnet in the main VPC |
| main\_vpc\_private\_subnet\_2\_id | ID of the second private subnet in the main VPC |
| main\_vpc\_private\_subnet\_3\_id | ID of the third private subnet in the main VPC |
| main\_vpc\_public\_route\_table\_id | ID of the public route table in the main VPC |
| main\_vpc\_public\_subnet\_1\_id | ID of the public subnet in the main VPC |
| postgres\_database\_arn | ARN of the main Braintrust Postgres database |
| quarantine\_vpc\_id | ID of the quarantine VPC that user functions run inside of. |
| rds\_security\_group\_id | ID of the security group for the RDS instance |
| redis\_arn | ARN of the Redis instance |
| redis\_security\_group\_id | ID of the security group for the Elasticache instance |
| remote\_support\_security\_group\_id | Security Group ID for the Remote Support bastion host. |
<!-- END_TF_DOCS -->