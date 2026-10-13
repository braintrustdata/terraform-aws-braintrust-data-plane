# Sandbox Service

This module deploys Sandbox Service into the main data-plane VPC alongside the
existing Lambda sandbox backend. The VPC can be module-managed or caller-provided;
the service uses the root module's three numbered private subnet inputs.

Terraform owns the private EKS cluster, system node group, launch templates,
security groups, IAM roles, Pod Identity associations, private DNS zone, bootstrap
Lambdas, three Secrets Manager secrets and a private Secrets Manager endpoint. Worker nodes use local NVMe storage and
nested virtualization. System nodes run DNS, the worker controller and autoscaler.

The release stack owns the worker node group, TLS provisioning and Helm release.
It uses published bootstrap and chart artifacts pinned in `VERSIONS.json`.
Installing the chart from a VPC-local Lambda supports a private EKS endpoint in
the first apply without requiring Kubernetes access from the Terraform runner.
Private keys are generated in Secrets Manager and never read into Terraform state.
The installer uses an endpoint-specific Secrets Manager URL with access limited
to its role and the two TLS bundles; existing VPC private DNS remains unchanged.

The workers' inbound rules allow the controller and the named
`authorized_security_groups` on TCP 9400. Node egress allows the private Kubernetes
API, cluster DNS and public IPv4 destinations for image downloads and AWS APIs.
Public prefix lists exclude private, shared, loopback and link-local ranges.
Sandbox guest network policy is enforced by Sandbox Service; these host rules do
not replace guest isolation. Connecting workers to Loop's private egress gateway
is owned by the root module, where both security groups are available.

Existing VPCs must provide DNS support, available subnet addresses and outbound
connectivity to public image registries, AWS APIs and the artifact bucket.
S3 endpoint policies must permit downloads from the regional `braintrust-cf-*`
artifact bucket, and any existing private AWS API endpoints must permit the
system nodes to reach the required APIs.
The module does not change existing routes or VPC DNS settings.
Choose a region and Availability Zones that offer the configured worker types.
This adds an EKS cluster, one system instance, worker instances and a three-AZ
Secrets Manager interface endpoint; it does not
reuse the Lambda sandbox VPC.

Hardware changes create a new worker pool while CloudFormation retains the old
pool. If the operation that creates a pool rolls back, CloudFormation deletes
that new pool so the next apply can reuse its name. The release installer includes retained pools in autoscaling and lowers
their minimum capacity to zero. The chart controller drains occupied sandboxes
before retiring workers; long-lived sandboxes can keep an old pool active after
Terraform completes. Image changes update the chart without replacing the pool.
An apply confirms chart installation and admission checks, not completed draining.

Deletion requests a worker drain and fails while workers are occupied. Drain the
service and inspect the chart's `sandbox-rollout` status before retrying deletion.
Retained EKS node groups must be removed once empty before deleting the cluster.
Do not remove the cluster, node roles or network rules while a retained pool is active.

This deployment module exposes the endpoint and client TLS secret ARN for Loop
Runtime integration. Deploying it alone does not change Loop's default provider,
Lambda image, connector or IAM permissions.
