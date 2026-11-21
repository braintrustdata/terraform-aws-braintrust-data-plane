# Sandbox Service

This module deploys a dedicated private EKS cluster for Firecracker workers in
the main data-plane VPC. It requires three dedicated private subnets in distinct
availability zones. The root VPC module creates these subnets for a managed VPC;
callers using an existing VPC supply their own dedicated subnets. Application
subnets are rejected. Existing subnet routes, ACLs and VPC DNS settings are left
under the caller's control.

Terraform owns the cluster, system node group, launch templates, security groups,
IAM roles, Pod Identity associations, private DNS zone, bootstrap Lambdas, TLS
secret containers, private Secrets Manager endpoint and filesystem checkpoint
bucket. Workers use local NVMe storage and nested virtualization. System nodes
run cluster DNS, the worker controller and autoscaler. Node CNI permissions allow
ENI creation only in the three dedicated subnets.

The release stack owns worker node groups, TLS provisioning and the Helm release.
Its chart and bootstrap package are pinned to published content-addressed
artifacts in `VERSIONS.json`. The VPC-local installer reaches the private EKS
endpoint without requiring Kubernetes access from the Terraform runner. TLS
private keys are generated in Secrets Manager and never read into Terraform
state. An endpoint-specific Secrets Manager URL avoids changing VPC private DNS.

Inbound worker rules allow the controller and `authorized_security_groups` on
TCP 9400. Authorized callers can reach the Kubernetes API on TCP 443; Loop's
task role receives only the chart's worker-node-reader Kubernetes group.
Workers reach cluster DNS and the Kubernetes API through explicit security-group
references. Public IPv4 prefix lists exclude private, shared, loopback and
link-local addresses. This module owns a private NLB for Loop's forward proxy
on TCP 4002. The root authorizes that NLB to reach Loop; the Loop module owns its
inbound rule. This path uses no Lambda sandbox resources.

Managed subnets have a separate ACL allowing cluster traffic, runtime access,
proxy access and public HTTPS. Return ports 32768–65535 are permitted for
runtime connections, and 1024–65535 for public HTTPS replies to the release Lambda
and nodes. A caller-provided subnet policy must
permit those paths. Security groups and guest network policy remain necessary;
the return-port allowances are stateless, and AWS subnet ACLs do not filter
Amazon-provided DNS or instance metadata. Use dedicated subnet ranges with
enough free addresses for worker nodes and CNI allocations.

Existing VPCs must provide DNS support and outbound connectivity to image
registries, AWS APIs and the regional `braintrust-cf-*` artifact bucket. A restricted
module-managed S3 endpoint permits reads of the pinned chart and response uploads
to CloudFormation's regional response bucket for this stack automatically.
The stack's response permission remains until VPC removal so disabling Sandbox
Service can complete its CloudFormation deletion callbacks.
Caller-managed S3 endpoint policies must permit those same requests. If caller-managed private AWS API
endpoints override public DNS, authorize their required traffic in both the
endpoint and node security groups and the subnet ACLs. The root exposes worker
and system security group IDs for those caller-owned rules. Worker types must be
available in the selected region and availability zones. This deployment adds EKS, EC2 and
three-AZ Secrets Manager endpoint charges.

Hardware, subnet, Kubernetes-version and launch-template changes create a new
worker pool. The release stack retains replaced pools while the controller
drains occupied sandboxes. A failed creation rolls back its new pool. Image-only
changes update the chart without replacing the hardware pool. Apply completion
confirms chart installation, not completed worker retirement.

Filesystem retention uses a dedicated encrypted private S3 bucket and a worker
Pod Identity scoped to its checkpoint prefix. Workers receive no API or
Brainstore bucket permissions. Checkpoints restore the last completed filesystem
state; they do not transfer Lambda files or preserve running process memory.
The bucket has no object expiration or force-delete setting. A nonempty bucket
blocks Terraform deletion until its contents are explicitly removed or the
bucket is preserved outside this module.

The root's `enable_sandbox_service` switch deploys the fleet and changes Loop's
backend in one apply. Every chat starts a fresh Sandbox Service sandbox; existing
Lambda files and processes are discarded. The Lambda sandbox infrastructure and
its runtime lifecycle policy are removed. Enabling configures Loop's service
image, mTLS files, private discovery and private egress URL. TLS
uses native ECS secret injection into an initialization container; the Loop task
role has no Secrets Manager access. Selecting a different backend creates fresh
sandbox environments without recovering prior files or processes.

For subsequent fleet removal, drain the service before disabling it. Deletion
requests a drain and fails while workers remain occupied. Inspect the chart's
`sandbox-rollout` status before retrying. Empty retained node groups must be
removed before cluster deletion. Keep node roles, network rules and checkpoint
storage available until draining and any required recovery are complete.
