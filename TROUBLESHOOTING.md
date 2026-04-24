# Troubleshooting

Operational runbooks for routine failures during `terraform apply` / `terraform destroy`. Scoped to the EKS Auto Mode deployment mode (`create_eks_cluster = true`) unless otherwise noted.

Disaster-recovery scenarios (state mismatch between Terraform and AWS caused by out-of-band changes) belong in [`RECOVERY.md`](RECOVERY.md) instead.

## EKS mode: `helm_release` hangs on destroy because of a finalizer

### Symptom

`terraform destroy` shows `Still destroying... [id=braintrust, Nm Xs elapsed]` for many minutes on the `helm_release.braintrust` resource, eventually timing out.

### Cause

When helm tears down the api Service, the AWS Load Balancer Controller holds a `service.eks.amazonaws.com/resources` finalizer on it while it drains and deregisters target group targets. Default drain delay is 300 seconds, and in some broken-state scenarios (cluster never had healthy nodes, earlier install failed, etc.) the drain never completes cleanly and the finalizer hangs for the full timeout.

Commit `fc11624` shipped `service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: deregistration_delay.timeout_seconds=0` on the api Service to prevent this on fresh destroys. If you're destroying a deployment that predates that commit, or hitting this on a broken-state cluster, the manual fix is below.

### Recovery

In another terminal, while `terraform destroy` is still running:

```
aws --profile <profile> --region <region> eks update-kubeconfig --name <deployment_name>-eks
kubectl -n braintrust patch svc braintrust-api --type merge -p '{"metadata":{"finalizers":null}}'
```

The helm uninstall inside Terraform will converge within ~30 seconds.

## EKS mode: EIP quota exhaustion on fresh apply

### Symptom

`terraform apply` errors on `aws_eip.nat_public_ip` with:

```
Error: creating EC2 EIP: AddressLimitExceeded: The maximum number of addresses has been reached.
```

The apply then hangs on other resources (notably `helm_release.braintrust`) that were started in parallel before the EIP error surfaced.

### Cause

AWS default quota is 5 EIPs per region per account. Each Braintrust deployment needs 1 EIP for its NAT Gateway. If other deployments or resources in the account already consume 5, the new deployment can't get an EIP, which blocks NAT Gateway creation, which blocks the private-subnet NAT route, which blocks pod outbound traffic, which blocks the helm_release.

### Recovery

Free up an EIP slot — request a quota increase via `aws service-quotas request-service-quota-increase --service-code ec2 --quota-code L-0263D0A3 --desired-value 10 --region <region>` (usually approved in minutes), or destroy another unused deployment, or release an unattached EIP (`aws ec2 describe-addresses` to find candidates).

Then clean up the partially-installed Helm release before re-applying:

```
aws --profile <profile> --region <region> eks update-kubeconfig --name <deployment_name>-eks
helm -n braintrust uninstall braintrust 2>/dev/null
helm -n braintrust uninstall brainstore-nodepool 2>/dev/null
```

Then `terraform apply` again. Terraform creates the missing EIP + NAT Gateway + private route, and the helm_release installs cleanly now that nodes have outbound connectivity.

## EKS mode: pods stuck Pending after first apply

### Symptom

After a successful `terraform apply`, pods in the `braintrust` namespace show `Pending` status indefinitely. `kubectl describe pod` shows `FailedScheduling: no nodes available to schedule pods`, and `kubectl get nodeclaims` shows Karpenter NodeClaims being created but never becoming Ready.

### Cause

Most common: Karpenter successfully calls `RunInstances` and the EC2 instance boots, but the kubelet on the instance can't reach the EKS public API endpoint. From the EC2 instance's console output (`aws ec2 get-console-output --instance-id <id> --latest`), you'll see repeated `dial tcp ...:443: i/o timeout` on the API endpoint. Almost always this means the NAT Gateway isn't providing outbound connectivity — either because it was never created (EIP quota failure, see above), or the private subnet's route table is missing the `0.0.0.0/0 → NAT` route.

### Recovery

Verify the NAT path:

```
AWS_PAGER='' aws --profile <profile> --region <region> ec2 describe-nat-gateways --filter "Name=tag:BraintrustDeploymentName,Values=<deployment_name>" --query 'NatGateways[].[NatGatewayId,State]' --output table
AWS_PAGER='' aws --profile <profile> --region <region> ec2 describe-route-tables --filters "Name=tag:Name,Values=<deployment_name>-main-private-rt" --query 'RouteTables[0].Routes[]' --output table
```

If the NAT Gateway is missing, fix the EIP quota issue (prior section). If the route is missing but the NAT exists, this points at an incomplete Terraform apply — `terraform apply` again should reconcile.

## Lambda mode: `dump-logs.sh` for log extraction

`scripts/dump-logs.sh` pulls CloudWatch logs for the deployment's Lambdas + EC2 Brainstore into a local `logs-<deployment_name>/` directory. Usage:

```
./scripts/dump-logs.sh <deployment_name> [--minutes N] [--service <svc1,svc2,...|all>]
```

This path does NOT work in EKS mode. The Braintrust Helm chart does not ship container logs to CloudWatch, and this module does not install a log-shipping sidecar or DaemonSet. In EKS mode, pod logs are reachable only via `kubectl logs`. Restoring CloudWatch-parity log shipment is a tracked follow-up (likely via an opt-in `amazon-cloudwatch-observability` addon); not yet implemented.
