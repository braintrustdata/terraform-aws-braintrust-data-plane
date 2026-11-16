#!/bin/bash
set -euo pipefail

# Help prevent immediate failure if another background process holds apt's lock.
echo 'DPkg::Lock::Timeout "60";' > /etc/apt/apt.conf.d/99apt-lock-retry
echo 'Acquire::Retries "5";' >> /etc/apt/apt.conf.d/99apt-lock-retry
sed -i "s|http://[a-z0-9-]\+\.ec2\.ports\.ubuntu\.com|http://ports.ubuntu.com|g" /etc/apt/sources.list.d/ubuntu.sources
rm -rf /var/lib/apt/lists/*
apt-get clean
apt-get update

# Ubuntu does not ship the CloudFormation helpers. Use an isolated environment
# rather than modifying Ubuntu's externally managed system Python installation.
apt-get install -y python3-venv curl ca-certificates
python3 -m venv /opt/aws-cfn-bootstrap
/opt/aws-cfn-bootstrap/bin/pip install --retries 5 \
  https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz

# These instances are owned by Terraform, so authenticate with their IAM role
# explicitly instead of CloudFormation's credentialless stack-membership check.
exec /opt/aws-cfn-bootstrap/bin/cfn-init \
  --stack '${stack_id}' \
  --resource BrainstoreInit \
  --region '${aws_region}' \
  --role '${role_name}'
