# Recovery

Disaster-recovery runbooks for the EKS Auto Mode deployment mode (`create_eks_cluster = true`). Scenarios here involve significant state mismatch between Terraform and AWS — recovery requires state-level intervention, not just a re-run of `terraform apply`.

Routine apply/destroy failures belong in [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) instead.

## Out-of-band cluster deletion

### Symptom

`terraform plan` or `terraform apply` fails at the refresh step with an error like:

```
Error: reading EKS Cluster (<deployment_name>-eks): couldn't find resource
```

The EKS cluster no longer exists in AWS, but Terraform state still references it (and many Kubernetes/Helm resources that depended on it).

### Cause

The EKS cluster was destroyed outside Terraform — AWS console, a stray `aws eks delete-cluster`, an account-cleanup script, etc. The module's kubernetes/helm provider configuration reads cluster endpoint + CA from module outputs that trace back to the `aws_eks_cluster` resource; with the cluster gone, those outputs become unreadable, so refresh fails before Terraform can plan or apply anything.

### Recovery

1. List the orphaned Kubernetes and Helm resources in state:

   ```
   terraform state list | grep -E "kubernetes_|helm_release"
   ```

2. Remove each of them from Terraform state. They already don't exist in AWS/Kubernetes (the cluster is gone), so this is a pure state-cleanup operation:

   ```
   terraform state rm '<address_1>' '<address_2>' ...
   ```

3. Re-run `terraform apply`. Terraform plans a fresh creation of the cluster, Pod Identity associations, namespace, secret, and Helm releases.

Expected runtime to recreate is similar to a fresh deploy (~15 minutes).

### When this runbook does NOT apply

`terraform destroy` handles in-band cluster deletion correctly — the dependency graph drains Kubernetes resources before destroying the cluster. This runbook is only needed when the cluster is destroyed out-of-band while in-cluster state still exists in Terraform.

### Why the module accepts this failure mode

The EKS module sources the kubernetes/helm provider configuration from module outputs rather than a `data.aws_eks_cluster` lookup. This is what enables single-apply bootstrap — on the first run, module outputs are "known after apply" and Terraform defers provider resolution until the cluster exists. A data source would've read at refresh (pre-plan) and failed the first `terraform plan`, requiring a two-step `-target`'d apply.

The tradeoff: if the cluster goes missing between applies (out-of-band deletion), the same mechanism that deferred provider resolution now fails to read the missing cluster. The recovery ritual above is the cost. For the target audience of sophisticated self-hosted-data-plane operators this is an acceptable trade; a broader-audience module might choose two-step apply instead.
