#!/bin/bash
set -euo pipefail

# ── Logging ──────────────────────────────────────────────────────────────────
log()  { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] INFO  $*" >&2; }
die()  { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] FATAL $*" >&2; exit 1; }

# ── Resolve jq binary for current architecture ────────────────────────────────
resolve_jq() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "/opt/bin/jq-linux-amd64" ;;
        aarch64) echo "/opt/bin/jq-linux-arm64"  ;;
        *)        die "Unsupported architecture: $arch" ;;
    esac
}

JQ=$(resolve_jq)
[[ -x "$JQ" ]] || die "jq binary not found or not executable: $JQ"

# ── Validate required environment variables ───────────────────────────────────
require_env() {
    local missing=()
    for var in "$@"; do
        [[ -n "${!var:-}" ]] || missing+=("$var")
    done
    (( ${#missing[@]} == 0 )) || die "Missing required environment variables: ${missing[*]}"
}

require_env AWS_SESSION_TOKEN DATABASE_SECRETS_ARN PG_HOST PG_PORT

# ── Fetch secret from AWS Secrets Manager via Lambda extension ────────────────
log "Fetching database credentials from Secrets Manager (ARN: $DATABASE_SECRETS_ARN)"

AWS_SM_RESPONSE=$(
    curl --silent --show-error --fail --max-time 5 \
        -H "X-Aws-Parameters-Secrets-Token: $AWS_SESSION_TOKEN" \
        "http://localhost:2773/secretsmanager/get?secretId=${DATABASE_SECRETS_ARN}"
) || die "Failed to retrieve secret from Secrets Manager extension (is the Lambda extension running?)"

[[ -n "$AWS_SM_RESPONSE" ]] || die "Secrets Manager returned an empty response"

# ── Parse credentials ─────────────────────────────────────────────────────────
parse_secret() {
    local key="$1"
    local value
    value=$(echo "$AWS_SM_RESPONSE" | "$JQ" -r --arg key "$key" \
        '.SecretString | fromjson | .[$key] // empty') \
        || die "jq failed to parse Secrets Manager response"
    [[ -n "$value" ]] || die "Key '$key' missing or null in secret JSON"
    echo "$value"
}

PG_USERNAME=$(parse_secret "username")
PG_PASSWORD=$(parse_secret "password")

export PG_USERNAME PG_PASSWORD
export PG_URL="postgres://${PG_USERNAME}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/postgres"

log "Database credentials loaded; PG_URL configured for host=${PG_HOST} port=${PG_PORT}"

# ── Hand off to container command ─────────────────────────────────────────────
[[ $# -gt 0 ]] || die "No command provided to exec"
exec "$@"
