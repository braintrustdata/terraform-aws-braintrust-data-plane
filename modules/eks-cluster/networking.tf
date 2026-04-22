# Tag private subnets so the AWS Load Balancer Controller can auto-discover
# them when creating internal NLBs.
resource "aws_ec2_tag" "private_subnet_internal_elb" {
  count       = length(var.private_subnet_ids)
  resource_id = var.private_subnet_ids[count.index]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

# CloudFront's managed prefix list for origin-facing traffic.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# NLB security group: allow CloudFront IP ranges on the API port (8000).
resource "aws_security_group" "nlb_cloudfront" {
  name   = "${var.deployment_name}-nlb-cloudfront"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = "${var.deployment_name}-nlb-cloudfront" }, local.common_tags)
}

# Allow the NLB to reach the EKS nodes on the default NodePort range.
resource "aws_vpc_security_group_ingress_rule" "eks_nodes_from_nlb" {
  security_group_id            = module.eks.node_security_group_id
  referenced_security_group_id = aws_security_group.nlb_cloudfront.id
  from_port                    = 30000
  to_port                      = 32767
  ip_protocol                  = "tcp"
}

# Pre-create the NLB so its ARN is known before the Load Balancer Controller
# runs — CloudFront VPC Origin requires the NLB ARN at plan time. The LB
# Controller adopts this NLB via the `aws-load-balancer-name` annotation
# emitted by the Braintrust Helm chart in the eks-deploy submodule.
#
# NLB security groups must be attached at creation time (they cannot be
# added later), which is why this is pre-created rather than handed off
# entirely to the Load Balancer Controller.
resource "aws_lb" "api" {
  name               = "${var.deployment_name}-api-nlb"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb_cloudfront.id]
  subnets            = var.private_subnet_ids

  tags = merge({ Name = "${var.deployment_name}-api-nlb" }, local.common_tags)
}
