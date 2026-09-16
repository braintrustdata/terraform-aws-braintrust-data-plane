#!/usr/bin/env bash
set -euo pipefail

exec > >(tee /var/log/braintrust-observability-user-data.log | logger -t braintrust-observability-user-data -s 2>/dev/console) 2>&1

export DEBIAN_FRONTEND=noninteractive

OBSERVABILITY_STACK_DIR="${observability_stack_dir}"
OBSERVABILITY_PACKAGE="/tmp/braintrust-observability.zip"

apt_get_install() {
  apt-get install -y "$@" || {
    sleep 10
    apt-get update
    apt-get install -y "$@"
  }
}

install_aws_cli() {
  if command -v aws >/dev/null 2>&1; then
    return
  fi

  local arch
  case "$(uname -m)" in
    aarch64 | arm64)
      arch="aarch64"
      ;;
    x86_64 | amd64)
      arch="x86_64"
      ;;
    *)
      echo "Unsupported architecture for AWS CLI: $(uname -m)" >&2
      exit 1
      ;;
  esac

  local installer_dir="/tmp/awscli"
  rm -rf "$installer_dir" /tmp/awscliv2.zip
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$arch.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d "$installer_dir"
  "$installer_dir/aws/install" --update
}

apt-get update
apt_get_install ca-certificates curl docker.io unzip
install_aws_cli

systemctl enable --now docker

if ! docker compose version >/dev/null 2>&1; then
  apt_get_install docker-compose-v2 || apt_get_install docker-compose
fi

cat > /usr/local/bin/braintrust-observability-compose <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

if docker compose version >/dev/null 2>&1; then
  exec docker compose "$@"
fi

if command -v docker-compose >/dev/null 2>&1; then
  exec docker-compose "$@"
fi

echo "Neither 'docker compose' nor 'docker-compose' is installed" >&2
exit 1
SCRIPT
chmod +x /usr/local/bin/braintrust-observability-compose

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
ExecStart=/usr/local/bin/braintrust-observability-compose up -d
ExecStop=/usr/local/bin/braintrust-observability-compose down
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
