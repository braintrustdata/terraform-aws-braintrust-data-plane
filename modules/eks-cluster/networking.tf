# Tag private subnets so the AWS Load Balancer Controller can discover them for
# internal load balancers.
resource "aws_ec2_tag" "private_subnet_internal_elb" {
  count       = length(var.subnet_ids)
  resource_id = var.subnet_ids[count.index]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.enable_cloudfront_nlb_ingress ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "nlb_cloudfront" {
  count       = var.enable_cloudfront_nlb_ingress ? 1 : 0
  name        = "${var.deployment_name}-nlb-cloudfront"
  description = "Allow CloudFront VPC Origin traffic to the Braintrust API NLB"
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name                     = "${var.deployment_name}-nlb-cloudfront"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "nlb_from_cloudfront" {
  count             = var.enable_cloudfront_nlb_ingress ? 1 : 0
  security_group_id = aws_security_group.nlb_cloudfront[0].id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront[0].id
  from_port         = 8000
  to_port           = 8000
  ip_protocol       = "tcp"
  description       = "CloudFront VPC Origin to Braintrust API"
}

resource "aws_vpc_security_group_egress_rule" "nlb_all_egress" {
  count             = var.enable_cloudfront_nlb_ingress ? 1 : 0
  security_group_id = aws_security_group.nlb_cloudfront[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow NLB egress to EKS nodes"
}

resource "aws_vpc_security_group_ingress_rule" "eks_nodes_from_nlb" {
  count                        = var.enable_cloudfront_nlb_ingress ? 1 : 0
  security_group_id            = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.nlb_cloudfront[0].id
  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
  description                  = "Braintrust API NLB to EKS NodePorts"
}

# Pre-create the NLB so CloudFront VPC Origin can reference its ARN at plan
# time. The AWS Load Balancer Controller adopts this NLB through the
# service.beta.kubernetes.io/aws-load-balancer-name annotation in the Helm
# values emitted by the eks-deploy module.
resource "aws_lb" "api" {
  count              = var.enable_cloudfront_nlb_ingress ? 1 : 0
  name               = "${var.deployment_name}-api-nlb"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb_cloudfront[0].id]
  subnets            = var.subnet_ids

  tags = merge(
    {
      Name                     = "${var.deployment_name}-api-nlb"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}
