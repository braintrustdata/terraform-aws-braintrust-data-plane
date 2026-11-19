# Sandbox Service

This module deploys a dedicated private EKS cluster for Firecracker workers in
the main data-plane VPC. It requires three dedicated private subnets in distinct
availability zones. The root VPC module creates these subnets for a managed VPC;
callers using an existing VPC supply their own dedicated subnets. Application
subnets are rejected. Existing subnet routes, ACLs and VPC DNS settings are left
under the caller's control.

Terraform owns the cluster, system node group, launch templates, security groups,
worker node group, IAM roles, Pod Identity associations, private DNS zone,
private Secrets Manager endpoint and filesystem checkpoint bucket. Helm owns
the Kubernetes workloads. Workers use local NVMe storage and nested virtualization. System nodes
run cluster DNS, the worker controller and autoscaler. Node CNI permissions allow
ENI creation only in the three dedicated subnets.

The module installs the published Sandbox Service chart directly through the
caller's Helm provider. There is no CloudFormation stack or installer Lambda.
The root integrates with ECS Loop Runtime in this iteration; it does not deploy
an EKS application. Worker deployment inputs use subnet IDs, security-group
maps and secret ARNs, and its outputs expose the private service and Kubernetes
connection details independently of the application compute platform.

## Helm provider and access

The Terraform runner must reach the private EKS API on TCP 443. For a managed
VPC, run it in one of the main application private subnets and pass its security
group through `sandbox_service_kubernetes_api_authorized_security_groups`.
For an existing VPC, the caller also owns the routing and ACL rules for its runner.
The runner's security group must allow outbound TCP 443 to the EKS endpoint.
The module grants the AWS provider's IAM principal cluster administration for
Helm installation. Configure Helm's AWS CLI authentication with that same IAM
role or user, region and credential profile, including any role assumption:

```hcl
provider "helm" {
  kubernetes = {
    host = module.braintrust-data-plane.sandbox_service_kubernetes_api_url
    cluster_ca_certificate = base64decode(module.braintrust-data-plane.sandbox_service_kubernetes_ca)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--region", "us-east-1",
        "--cluster-name", module.braintrust-data-plane.sandbox_service_cluster_name,
      ]
    }
  }
}
```

Keep this provider configuration available when disabling the feature or
removing the module so Terraform can uninstall the Helm releases. Before
switching `enable_sandbox_service` to false, replace these module-output
references with the cluster connection values from the previous apply; disabling
the feature makes its root outputs null. Remove the provider configuration only
after the uninstall completes.

## Existing TLS bundles

Before enabling the service, supply these Secrets Manager secrets in the same
account and region as the deployment. The module neither creates nor deletes
these secrets, and never reads their private-key values into Terraform state.

| Input | `cert` and `key` | `ca_cert` |
| --- | --- | --- |
| `sandbox_service_server_tls_secret_arn` | Server certificate chain and matching private key | CA bundle trusted for client authentication |
| `sandbox_service_client_tls_secret_arn` | Client certificate chain and matching private key | CA bundle trusted for server authentication |

Each secret is a JSON object with nonempty PEM strings named `cert`, `key` and
`ca_cert`. The server certificate must include the DNS SAN
`nodes.<deployment_name>.sandbox.internal` and server-auth extended key usage.
The client certificate needs client-auth extended key usage. Certificates can
come from the deployer's existing PKI, including a private CA; they do not need
to be publicly trusted. Keep CA signing keys separate from these leaf bundles.
If both secrets use a customer-managed KMS key, supply its ARN through
`sandbox_service_tls_kms_key_arn` and authorize the module's reader roles in the
key policy. Otherwise use the default Secrets Manager encryption key.

A namespace-scoped External Secrets controller reads only those two secrets
through an endpoint-specific Secrets Manager URL, without changing VPC private
DNS. Its dedicated Pod Identity has no write permissions. Workers receive no
Secrets Manager permissions. ECS uses native secret injection for the client
bundle; the Loop task role cannot read Secrets Manager.

Terraform reads current version metadata and pins both Kubernetes bundles and
the ECS client to those versions. After publishing rotated bundles, run apply
to update consumers together. Plan certificate overlap through the deployer's
PKI process; certificate issuance and renewal are outside this module.

Inbound worker rules allow the controller and `authorized_security_groups` on
TCP 9400. Authorized callers can reach the Kubernetes API on TCP 443; Loop's
task role receives only the chart's worker-node-reader Kubernetes group.
Workers reach cluster DNS and the Kubernetes API through explicit security-group
references. Public IPv4 prefix lists exclude private, shared, loopback and
link-local addresses. This module owns a private NLB for Loop's forward proxy
on TCP 4002. The root authorizes that NLB to reach Loop; the Loop module owns its
inbound rule. This path uses no Lambda sandbox resources.

Managed subnets have a separate ACL allowing cluster traffic, runtime access,
proxy access and public HTTPS. Linux return ports 32768–65535 are permitted for
the runtime and public HTTPS connections. A caller-provided subnet policy must
permit those paths. Security groups and guest network policy remain necessary;
the return-port allowances are stateless, and AWS subnet ACLs do not filter
Amazon-provided DNS or instance metadata. Use dedicated subnet ranges with
enough free addresses for worker nodes and CNI allocations.

Existing VPCs must provide DNS support and outbound connectivity to image
registries, AWS APIs and the regional `braintrust-cf-*` artifact bucket. S3
endpoint policies must admit that bucket. If caller-managed private AWS API
endpoints override public DNS, authorize their required traffic in both the
endpoint and node security groups and the subnet ACLs. The root exposes worker
and system security group IDs for those caller-owned rules. Worker types must be
available in the selected region and availability zones. This deployment adds EKS, EC2 and
three-AZ Secrets Manager endpoint charges. The Helm runner also needs HTTPS
access to the chart repositories.

Hardware, subnet, Kubernetes-version and launch-template changes create a new
Terraform-managed worker pool and remove the old one. These changes can reset
running sandboxes. There are no retained worker pools outside Terraform state.
Image-only changes update the chart without replacing the hardware pool.

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

Disabling the feature or removing the fleet is also a hard cutover. Helm skips
the chart's graceful-uninstall hook; occupied sandboxes do not block uninstall.
Preserve the checkpoint bucket until its data is no longer needed.
