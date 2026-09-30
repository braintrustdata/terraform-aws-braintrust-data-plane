# EKS and Kubernetes permission preparation

This is a forward-looking permissions baseline, not an EKS deployment or an
implemented Kubernetes access path. Networking, cluster configuration, access
activation, and session handling are outside this update.

## AWS permissions

`deployment-eks-policy.json` prepares Deployment to manage named EKS clusters,
managed node groups, and add-ons in the configured account and Region. It also
permits fixed access entries for Deployment, Support, and Observer, with one
predefined Kubernetes group per role. It does not permit arbitrary principals,
group updates, managed access-policy association, or a standing Diagnostics entry.
Access-entry tag management is limited to the bootstrap's named management roles
in matching clusters; changing tags does not grant Kubernetes access. Entry
inspection returns its tags through `DescribeAccessEntry`.

Cluster creation requires a matching deployment tag, API access-entry mode, and
no automatic cluster-creator administrator grant. AWS does not support a resource
ARN restriction on `CreateCluster`; the module must also enforce the reserved
cluster name prefix. Subsequent lifecycle actions use that name prefix.

The deployment boundary and SCP allow passing matching cluster roles to EKS;
the EKS policy permits only its cluster and managed-node-group service-linked
roles. Existing EC2 `PassRole` covers node roles. This is not a full baseline
for EKS Auto Mode, Fargate, or a selected pod-identity implementation.

Support and Observer gain EKS health/configuration discovery, not cluster
administration. Diagnostics has similar target discovery. No role receives
`eks:*`.

## Kubernetes permissions

AWS IAM actions do not define what `kubectl` can do. Kubernetes authorization
requires access entries and RBAC. The IAM `eks:AccessKubernetesApi` denial in
the routine policies restricts the AWS console viewer; it is not a general
`kubectl` deny.

| Role | Intended group and permissions |
| --- | --- |
| Deployment | `braintrust:deployment`: manage platform resources required by deployment; exact RBAC follows the future module |
| Observer | `braintrust:observer`: inspect selected workload configuration, status, events, and capacity |
| Support | Observer plus `braintrust:support`: scale existing workloads and HPAs; request pod eviction |
| Diagnostics | Selected inspection plus `braintrust:diagnostics`: application logs and container execution when activated |

[`policies/kubernetes-rbac-reference.yaml`](policies/kubernetes-rbac-reference.yaml)
defines the three human permission profiles, without bindings. Support would
receive both the Observer and Support profiles. Bind only within namespaces
managed by Braintrust; the reference does not grant cluster-wide human access.
Diagnostics bindings and activation are deferred, not made permanent by this file.

The human profiles exclude Secret reads, ConfigMap reads, arbitrary workload
creation/editing, RBAC administration, impersonation, service-account token
creation, privileged debug pods, and port forwarding. Workload reads can still
expose literal environment values or sensitive configuration: RBAC does not
redact individual fields. Keep credentials in Secrets, and validate the
information returned by the selected read APIs before enabling these profiles.

Do not substitute broad built-in View/Edit/Admin policies: View includes
application logs, and Edit exceeds the bounded Support profile. Workload
deployment itself remains privileged, as described in the primary README.

These permissions reduce foreseeable bootstrap changes; they do not guarantee
that the eventual Kubernetes implementation needs no additional permissions.
EKS lifecycle, role assumptions, controller identities, and effective RBAC must
be validated with that implementation before use.

References: [EKS access policies](https://docs.aws.amazon.com/eks/latest/userguide/access-policies.html),
[EKS policy contents](https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html),
[Kubernetes RBAC guidance](https://kubernetes.io/docs/concepts/security/rbac-good-practices/).
