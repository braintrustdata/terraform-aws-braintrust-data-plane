#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG_PATH="$SCRIPT_DIR/quota-config.json"
OVERRIDE_CONFIG_PATH="$SCRIPT_DIR/quota-config.override.json"
CONFIG_PATH="${CONFIG_PATH:-}"
if [[ -z "$CONFIG_PATH" ]]; then
  CONFIG_PATH="$DEFAULT_CONFIG_PATH"
  if [[ -f "$OVERRIDE_CONFIG_PATH" ]]; then
    CONFIG_PATH="$OVERRIDE_CONFIG_PATH"
  fi
fi
MODE="${1:-list}"
PROFILE="${AWS_PROFILE:-}"
AWS_ARGS=()
ACCOUNT_ID=""

usage() {
  cat <<'EOF'
Usage:
  bash managed-byoc/manage-quotas.sh [--profile PROFILE] [list|request]

Behavior:
  list    Show current account quota values and desired values from config.
  request If current quota is below desired_value, submit increase request.

Options:
  --profile, -p PROFILE   AWS profile to use (default: AWS_PROFILE env var)

Environment overrides:
  CONFIG_PATH=/path/to/quota-config.json  # explicit path wins over defaults
  AWS_PROFILE=profile-name                # default profile if --profile is not provided

Config precedence:
  1) CONFIG_PATH env var (if set)
  2) managed-byoc/quota-config.override.json (if present)
  3) managed-byoc/quota-config.json
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

compare_lt() {
  # Use awk for numeric comparison because bash -lt/-gt only support integers,
  # while Service Quotas values can be returned as decimals (e.g. 5.0).
  awk -v a="$1" -v b="$2" 'BEGIN { print (a < b) ? "1" : "0" }'
}

parse_config() {
  jq -r '.[] | [.service_code, .quota_code, .desired_value, .name] | @tsv' "$CONFIG_PATH"
}

MODE="list"
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--profile" || "${1:-}" == "-p" ]]; then
  PROFILE="${2:-}"
  if [[ -z "$PROFILE" ]]; then
    echo "Error: --profile requires a value." >&2
    exit 1
  fi
  shift 2
fi

if [[ $# -gt 0 ]]; then
  case "$1" in
    list|request)
      MODE="$1"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
fi

if [[ $# -gt 0 ]]; then
  echo "Unknown argument: $1" >&2
  echo "Expected ordering: [--profile PROFILE] [list|request]" >&2
  usage
  exit 1
fi

if [[ -n "$PROFILE" ]]; then
  AWS_ARGS=(--profile "$PROFILE")
fi

require_cmd aws
require_cmd jq

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Config file not found: $CONFIG_PATH" >&2
  exit 1
fi

# Validate config file is valid JSON before processing.
jq empty "$CONFIG_PATH" >/dev/null
# Validate required config keys are present and non-empty.
if ! jq -e 'all(.[]; (.service_code | type == "string" and length > 0) and (.quota_code | type == "string" and length > 0) and (.name | type == "string" and length > 0) and (.desired_value | type == "number"))' "$CONFIG_PATH" >/dev/null; then
  echo "Invalid quota config: each item must include non-empty service_code, quota_code, name, and numeric desired_value." >&2
  exit 1
fi

if ! ACCOUNT_ID="$(aws sts get-caller-identity "${AWS_ARGS[@]}" --query 'Account' --output text 2>/dev/null)"; then
  if [[ -n "$PROFILE" ]]; then
    echo "Failed to resolve AWS account for profile '$PROFILE'." >&2
  else
    echo "Failed to resolve AWS account using default AWS credentials/profile." >&2
  fi
  exit 1
fi

echo "Using AWS profile: ${PROFILE:-default}"
echo "Using AWS account: $ACCOUNT_ID"

if [[ "$MODE" == "request" ]]; then
  echo
  echo "Confirm to submit quota increase requests:"
  read -r -p "Continue? Type 'yes' to proceed: " APPROVAL
  if [[ "$APPROVAL" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi
echo
printf "%-70s %-12s %-12s %-24s %-22s %-12s\n" "QuotaName" "Current" "Desired" "Action" "Svc" "QuotaCode"
printf "%-70s %-12s %-12s %-24s %-22s %-12s\n" "----------------------------------------------------------------------" "------------" "------------" "------------------------" "----------------------" "------------"

while IFS=$'\t' read -r service_code quota_code desired_value quota_name; do
  if ! current_value="$(
    aws service-quotas get-service-quota \
      "${AWS_ARGS[@]}" \
      --service-code "$service_code" \
      --quota-code "$quota_code" \
      --query 'Quota.Value' \
      --output text 2>/dev/null
  )"; then
    printf "%-70s %-12s %-12s %-24s %-22s %-12s\n" \
      "$quota_name" "n/a" "$desired_value" "get-failed" "$service_code" "$quota_code"
    continue
  fi

  action="none"
  if [[ "$MODE" == "request" ]]; then
    if [[ "$(compare_lt "$current_value" "$desired_value")" == "1" ]]; then
      if request_id="$(
        aws service-quotas request-service-quota-increase \
          "${AWS_ARGS[@]}" \
          --service-code "$service_code" \
          --quota-code "$quota_code" \
          --desired-value "$desired_value" \
          --support-case-allowed \
          --query 'RequestedQuota.Id' \
          --output text 2>/dev/null
      )"; then
        action="requested:$request_id"
      else
        action="request-failed"
      fi
    else
      action="already-ok"
    fi
  else
    if [[ "$(compare_lt "$current_value" "$desired_value")" == "1" ]]; then
      action="needs-raise"
    else
      action="ok"
    fi
  fi

  printf "%-70s %-12s %-12s %-24s %-22s %-12s\n" \
    "$quota_name" "$current_value" "$desired_value" "$action" "$service_code" "$quota_code"
done < <(parse_config)
