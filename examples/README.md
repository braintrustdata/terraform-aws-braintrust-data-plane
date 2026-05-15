# Examples

Example configurations for deploying the Braintrust data plane on AWS. Copy the relevant directory into your own repository and customize it for your environment.

| Example | Description |
|---|---|
| [braintrust-data-plane](./braintrust-data-plane/) | Standard production-sized deployment. Start here for most use cases. |
| [braintrust-data-plane-sandbox](./braintrust-data-plane-sandbox/) | Minimal deployment for infrastructure testing. Downsized instances, no quarantine VPC, deletion protection disabled. Not for workload testing. |
| [braintrust-data-plane-external-eks-quarantine](./braintrust-data-plane-external-eks-quarantine/) | Deployment with an external EKS cluster and quarantine VPC for user-defined functions. |
| [eks-terraform-managed](./eks-terraform-managed/) | Terraform-managed node-group cluster example. Terraform creates the AWS data plane and EKS cluster, disables the bundled CloudFront/NLB ingress by default, and leaves the app install and ingress choice to the customer. |
| [eks-auto-mode](./eks-auto-mode/) | Full one-click Auto Mode example. Terraform creates the AWS data plane, EKS cluster, bundled CloudFront/NLB ingress, Kubernetes bootstrap resources, and the Braintrust application deployment. |
| [cloudfront-logging](./cloudfront-logging/) | Add-on example for enabling CloudFront access logging to S3. |

See the [self-hosting documentation](https://www.braintrust.dev/docs/guides/self-hosting/aws) for full setup instructions.
