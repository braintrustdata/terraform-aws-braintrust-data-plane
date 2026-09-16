#!/usr/bin/env bash
set -euo pipefail

exec > >(tee /var/log/braintrust-observability-user-data.log | logger -t braintrust-observability-user-data -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive

OBSERVABILITY_STACK_DIR="${observability_stack_dir}"
OBSERVABILITY_PACKAGE="/tmp/braintrust-observability.zip"

apt-get update
apt-get install -y awscli docker.io docker-compose-v2 unzip

systemctl enable --now docker

if ! systemctl list-unit-files | grep -Eq '^(amazon-ssm-agent|snap\.amazon-ssm-agent\.amazon-ssm-agent)\.service'; then
  snap install amazon-ssm-agent --classic || true
fi

systemctl enable --now amazon-ssm-agent || systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent || true

mkdir -p "$OBSERVABILITY_STACK_DIR"
aws s3 cp "s3://${observability_bucket}/${observability_key}" "$OBSERVABILITY_PACKAGE" --region "${aws_region}"
rm -rf "$OBSERVABILITY_STACK_DIR"/*
unzip -q "$OBSERVABILITY_PACKAGE" -d "$OBSERVABILITY_STACK_DIR"

cat > /etc/systemd/system/braintrust-observability.service <<UNIT
[Unit]
Description=Braintrust sandbox observability stack
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$OBSERVABILITY_STACK_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
RemainAfterExit=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now braintrust-observability.service

cat > "$OBSERVABILITY_STACK_DIR/.terraform-package-version" <<VERSION
${observability_zip_sha}
VERSION
