output "api_url" {
  value       = module.braintrust.api_url
  description = "Braintrust API URL to register in the Braintrust dashboard. Null until you enable bundled ingress or add your own ingress path."
}

output "connect_to_cluster" {
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${module.braintrust.eks_cluster_name}"
  description = "Command to configure kubectl for the EKS cluster."
}

output "eks_cluster_name" {
  value       = module.braintrust.eks_cluster_name
  description = "EKS cluster name."
}

output "eks_namespace" {
  value       = module.braintrust.eks_namespace
  description = "Kubernetes namespace where Braintrust is deployed."
}

output "cloudfront_distribution_domain_name" {
  value       = module.braintrust.cloudfront_distribution_domain_name
  description = "CloudFront distribution domain name. Null when bundled ingress is disabled."
}

output "cloudfront_distribution_hosted_zone_id" {
  value       = module.braintrust.cloudfront_distribution_hosted_zone_id
  description = "CloudFront hosted zone ID for Route53 alias records. Null when bundled ingress is disabled."
}

output "eks_nlb_name" {
  value       = module.braintrust.eks_nlb_name
  description = "Internal NLB name adopted by the Braintrust API Kubernetes service. Null when bundled ingress is disabled."
}

output "postgres_database_identifier" {
  value       = module.braintrust.postgres_database_identifier
  description = "RDS instance identifier."
}

output "postgres_database_secret_arn" {
  value       = module.braintrust.postgres_database_secret_arn
  description = "ARN of the Secrets Manager secret containing PostgreSQL credentials."
}

output "postgres_database_address" {
  value       = module.braintrust.postgres_database_address
  description = "Hostname of the PostgreSQL database."
}

output "postgres_database_port" {
  value       = module.braintrust.postgres_database_port
  description = "Port of the PostgreSQL database."
}

output "redis_endpoint" {
  value       = module.braintrust.redis_endpoint
  description = "Hostname of the ElastiCache Redis instance."
}

output "redis_port" {
  value       = module.braintrust.redis_port
  description = "Port of the ElastiCache Redis instance."
}

output "function_tools_secret_key" {
  value       = module.braintrust.function_tools_secret_key
  description = "Function secret key used by Braintrust application components."
  sensitive   = true
}

output "braintrust_secrets_command" {
  value       = <<-EOT
DB_SECRET_JSON="$(aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw postgres_database_secret_arn) \
  --region ${data.aws_region.current.region} \
  --query SecretString \
  --output text)"

DB_USER="$(jq -r '.username' <<<"$DB_SECRET_JSON")"
DB_PASS="$(jq -r '.password' <<<"$DB_SECRET_JSON")"

kubectl create secret generic braintrust-secrets \
  -n $(terraform output -raw eks_namespace) \
  --from-literal=PG_URL="postgresql://$${DB_USER}:$${DB_PASS}@$(terraform output -raw postgres_database_address):$(terraform output -raw postgres_database_port)/postgres?sslmode=require" \
  --from-literal=REDIS_URL="redis://$(terraform output -raw redis_endpoint):$(terraform output -raw redis_port)" \
  --from-literal=BRAINSTORE_LICENSE_KEY="<brainstore-license>" \
  --from-literal=FUNCTION_SECRET_KEY="$(terraform output -raw function_tools_secret_key)" \
  --dry-run=client -o yaml | kubectl apply -f -
EOT
  description = "Command to create or update the braintrust-secrets secret. Replace <brainstore-license> with a real license key before running."
}

output "braintrust_generated_values_yaml" {
  value = yamlencode({
    global = {
      orgName         = var.braintrust_org_name
      namespace       = module.braintrust.eks_namespace
      createNamespace = false
    }

    cloud = "aws"

    objectStorage = {
      aws = {
        brainstoreBucket = module.braintrust.brainstore_s3_bucket_name
        responseBucket   = module.braintrust.lambda_responses_s3_bucket_name
        codeBundleBucket = module.braintrust.code_bundle_s3_bucket_name
      }
    }

    skipPgForBrainstoreObjects = "all"
    brainstoreWalFooterVersion = "v3"

    api = {
      service = {
        type     = "ClusterIP"
        port     = 8000
        portName = "http"
      }
      serviceAccount = {
        name       = "braintrust-api"
        awsRoleArn = module.braintrust.eks_braintrust_api_role_arn
      }
      nodeSelector = {
        role = "services"
      }
      tolerations = [
        {
          key      = "dedicated"
          operator = "Equal"
          value    = "services"
          effect   = "NoSchedule"
        }
      ]
    }

    brainstore = {
      serviceAccount = {
        name       = "brainstore"
        awsRoleArn = module.braintrust.eks_brainstore_role_arn
      }
      reader = {
        nodeSelector = {
          role = "brainstore-reader"
        }
        tolerations = [
          {
            key      = "dedicated"
            operator = "Equal"
            value    = "brainstore"
            effect   = "NoSchedule"
          }
        ]
      }
      fastreader = {
        nodeSelector = {
          role = "brainstore-reader"
        }
        tolerations = [
          {
            key      = "dedicated"
            operator = "Equal"
            value    = "brainstore"
            effect   = "NoSchedule"
          }
        ]
      }
      writer = {
        nodeSelector = {
          role = "brainstore-writer"
        }
        tolerations = [
          {
            key      = "dedicated"
            operator = "Equal"
            value    = "brainstore"
            effect   = "NoSchedule"
          }
        ]
      }
    }
  })
  description = "Generated base Helm values for the Braintrust chart. Add ingress-specific overrides in a separate values.yaml."
}

output "braintrust_write_generated_values_command" {
  value       = "terraform output -raw braintrust_generated_values_yaml > ./braintrust-generated-values.yaml"
  description = "Command to write the generated Helm values to braintrust-generated-values.yaml in this directory."
}

output "braintrust_public_helm_command" {
  value       = "helm upgrade --install braintrust oci://public.ecr.aws/braintrust/helm/braintrust --namespace ${module.braintrust.eks_namespace} --create-namespace --values ./braintrust-generated-values.yaml --values ./values.yaml"
  description = "Command to install or upgrade the public Braintrust Helm chart using the generated base values plus your own ingress-specific overrides."
}
