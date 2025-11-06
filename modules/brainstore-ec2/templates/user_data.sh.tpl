#!/bin/bash

# Help prevent immediate failure of apt commands if another background process is holding the lock
echo 'DPkg::Lock::Timeout "60";' > /etc/apt/apt.conf.d/99apt-lock-retry

# Mount the local SSD if it exists
apt-get install -y nvme-cli mdadm
MOUNT_DIR="/mnt/tmp/brainstore"
mkdir -p "$MOUNT_DIR"

NVME_DEVICES=($(nvme list | grep 'Instance Storage' | awk '{print $1}'))
if [ "$${#NVME_DEVICES[@]}" -ge 2 ]; then
  echo "Multiple NVMe instance storage devices found: $${NVME_DEVICES[*]}"
  # Create RAID0 array
  mdadm --create --verbose /dev/md0 --level=0 --raid-devices=$${#NVME_DEVICES[@]} "$${NVME_DEVICES[@]}"
  # Wait for /dev/md0 to be available
  udevadm settle
  DEVICE="/dev/md0"
else
  DEVICE="$${NVME_DEVICES[0]}"
fi
if [ -n "$DEVICE" ]; then
  echo "Ephemeral device: $DEVICE"
  blkid "$DEVICE" >/dev/null || mkfs.ext4 -F "$DEVICE"
  mount "$DEVICE" "$MOUNT_DIR"
  chmod -R 0777 "$MOUNT_DIR"
  # Add to fstab using UUID rather than device name
  UUID=$(blkid -s UUID -o value "$DEVICE")
  echo "UUID=$UUID $MOUNT_DIR ext4 defaults 0 2" >> /etc/fstab
else
  echo "No ephemeral device found. Exiting with failure."
  exit 1
fi

# Raise the file descriptor limit
cat <<EOF > /etc/security/limits.d/brainstore.conf
# Root users has to be set explicitly
root soft nofile 65535
root hard nofile 65535
# All other users
* soft nofile 65535
* hard nofile 65535
EOF

# Set AWS region for CLI commands
export AWS_DEFAULT_REGION=${aws_region}

sudo snap install aws-cli --classic
# Set up docker log rotation
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
apt-get update
apt-get install -y docker.io jq earlyoom dstat
systemctl start docker
systemctl enable docker

# Install CloudWatch agent
arch=$(dpkg --print-architecture)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/$arch/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "logs": {
    "force_flush_interval": 5,
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/lib/docker/containers/*/*.log",
            "log_group_name": "/braintrust/${deployment_name}/brainstore",
            "log_stream_name": "{instance_id}/containers",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
sed -i 's/Restart=.*/Restart=always/' /etc/systemd/system/amazon-cloudwatch-agent.service
systemctl daemon-reload
systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent

# Get database credentials from Secrets Manager
DB_CREDS=$(aws secretsmanager get-secret-value --secret-id ${database_secret_arn} --query SecretString --output text)
DB_USERNAME=$(echo $DB_CREDS | jq -r .username)
DB_PASSWORD=$(echo $DB_CREDS | jq -r .password)

cat <<EOF > /etc/brainstore.env
# WARNING: Do NOT use quotes around values here. They get passed as literals by docker.
BRAINSTORE_VERBOSE=1
BRAINSTORE_PORT=${brainstore_port}
BRAINSTORE_INDEX_URI=s3://${brainstore_s3_bucket}/brainstore/index
BRAINSTORE_REALTIME_WAL_URI=s3://${brainstore_s3_bucket}/brainstore/wal
BRAINSTORE_LOCKS_URI=s3://${brainstore_s3_bucket}/locks
BRAINSTORE_METADATA_URI=postgres://$DB_USERNAME:$DB_PASSWORD@${database_host}:${database_port}/postgres
BRAINSTORE_WAL_URI=postgres://$DB_USERNAME:$DB_PASSWORD@${database_host}:${database_port}/postgres
BRAINSTORE_CACHE_DIR=/mnt/tmp/brainstore
BRAINSTORE_LICENSE_KEY=${brainstore_license_key}
BRAINSTORE_READER_ONLY_MODE=${is_dedicated_reader_node}
BRAINSTORE_TIME_BASED_RETENTION_OBJECT_ALL=${brainstore_enable_retention}
BRAINSTORE_CONTROL_PLANE_TELEMETRY=${monitoring_telemetry}
SERVICE_TOKEN_SECRET_KEY=${service_token_secret_key}
NO_COLOR=1
AWS_DEFAULT_REGION=${aws_region}
AWS_REGION=${aws_region}
BRAINSTORE_REDIS_URI=redis://${redis_host}:${redis_port}
BRAINSTORE_OBJECT_STORE_CACHE_FILE_SIZE=${brainstore_cache_file_size}
%{ for env_key, env_value in extra_env_vars ~}
${env_key}=${env_value}
%{ endfor ~}
EOF

if [ "${is_dedicated_writer_node}" = "true" ]; then
  # Until we are comfortable with stability
  echo '0 * * * * root /usr/bin/docker restart brainstore > /var/log/brainstore-restart.log 2>&1' > /etc/cron.d/restart-brainstore
fi

if [ -n "${internal_observability_api_key}" ]; then
  if [ -n "${internal_observability_env_name}" ]; then
    export DD_ENV="${internal_observability_env_name}"
  fi
  # Install Datadog Agent
  export DD_API_KEY="${internal_observability_api_key}"
  export DD_SITE="${internal_observability_region}.datadoghq.com"
  export DD_APM_INSTRUMENTATION_ENABLED=host
  export DD_APM_INSTRUMENTATION_LIBRARIES=java:1,python:3,js:5,php:1,dotnet:3
  bash -c "$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"
  usermod -a -G docker dd-agent

  cat <<EOF > /etc/datadog-agent/environment
DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT=0.0.0.0:4318
DD_COLLECT_EC2_TAGS=true
DD_COLLECT_EC2_TAGS_USE_IMDS=true
EOF
  # Configure Datadog Agent to collect Docker logs
  cat <<EOF >> /etc/datadog-agent/datadog.yaml
logs_enabled: true
listeners:
    - name: docker
config_providers:
    - name: docker
      polling: true
logs_config:
    container_collect_all: true
EOF
  # Configure Brainstore to send traces to Datadog
  cat <<EOF >> /etc/brainstore.env
BRAINSTORE_OTLP_HTTP_ENDPOINT=http://localhost:4318
EOF
  # Restart Datadog Agent to pick up new configuration
  systemctl restart datadog-agent
fi

BRAINSTORE_RELEASE_VERSION=${brainstore_release_version}
BRAINSTORE_VERSION_OVERRIDE=${brainstore_version_override}
BRAINSTORE_VERSION=$${BRAINSTORE_VERSION_OVERRIDE:-$${BRAINSTORE_RELEASE_VERSION}}

docker run -d \
  --network host \
  --name brainstore \
  --env-file /etc/brainstore.env \
  --restart always \
  -v /mnt/tmp/brainstore:/mnt/tmp/brainstore \
  public.ecr.aws/braintrust/brainstore:$${BRAINSTORE_VERSION} \
  web

%{ if custom_post_install_script != "" ~}
echo "Running custom post-install script..."
${custom_post_install_script}
%{ endif ~}
