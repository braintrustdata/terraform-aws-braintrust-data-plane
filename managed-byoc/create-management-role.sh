#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRUST_POLICY_PATH="$SCRIPT_DIR/policies/management-role-trust-policy.json"
ROLE_POLICY_PATH="$SCRIPT_DIR/policies/management-role-policy.json"

ROLE_NAME="${ROLE_NAME:-BraintrustManagementRole}"
PROFILE="${AWS_PROFILE:-default}"
INLINE_POLICY_NAME="${INLINE_POLICY_NAME:-BraintrustManagementRolePolicy}"
EXTERNAL_ID=""
MANAGEMENT_ROLE_ARN=""
MAX_SESSION_DURATION_SECONDS=3600

usage() {
  cat <<'EOF'
Usage:
  bash managed-byoc/create-management-role.sh [--profile PROFILE] [--role-name ROLE_NAME]

Options:
  --profile, -p    AWS profile to use (default: AWS_PROFILE env var, else "default")
  --role-name, -r  IAM role name to create or update (default: BraintrustManagementRole).
                   When updating an existing installation, pass the role's current name.
  --help, -h       Show this help

Environment:
  AWS_PROFILE         Default profile if --profile is not provided
  ROLE_NAME           Default role name if --role-name is not provided
  INLINE_POLICY_NAME  Name for inline role policy (default: BraintrustManagementRolePolicy)
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

generate_external_id() {
  local uuid=""
  if command -v uuidgen >/dev/null 2>&1; then
    uuid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  elif [[ -r /proc/sys/kernel/random/uuid ]]; then
    uuid="$(cat /proc/sys/kernel/random/uuid)"
  else
    echo "Missing UUID source: uuidgen or /proc/sys/kernel/random/uuid" >&2
    exit 1
  fi
  EXTERNAL_ID="braintrust-${uuid}"
}

resolve_external_id() {
  if aws iam get-role --profile "$PROFILE" --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    local existing
    existing="$(aws iam get-role \
      --profile "$PROFILE" \
      --role-name "$ROLE_NAME" \
      --output json | jq -r '.Role.AssumeRolePolicyDocument | (if type == "string" then fromjson else . end) | .Statement[0].Condition.StringEquals."sts:ExternalId" // empty')"
    if [[ -n "$existing" && "$existing" != "null" ]]; then
      EXTERNAL_ID="$existing"
      return
    fi
  fi
  generate_external_id
}

build_trust_policy() {
  jq --arg external_id "$EXTERNAL_ID" \
    '.Statement[0].Condition = {"StringEquals": {"sts:ExternalId": $external_id}}' \
    "$TRUST_POLICY_PATH"
}

# Renders the inline policy, replacing {{management_role_arn}} with the
# exact ARN AWS returned for this role so the self-modification deny targets it.
build_role_policy() {
  if [[ "$MANAGEMENT_ROLE_ARN" != arn:* ]]; then
    echo "Failed to resolve management role ARN (got '$MANAGEMENT_ROLE_ARN')." >&2
    exit 1
  fi
  local rendered
  rendered="$(jq --arg role_arn "$MANAGEMENT_ROLE_ARN" \
    '(.Statement[] | select(.Resource == "{{management_role_arn}}") | .Resource) = $role_arn' \
    "$ROLE_POLICY_PATH")"
  if grep -qF '{{management_role_arn}}' <<<"$rendered" || ! grep -qF "\"$MANAGEMENT_ROLE_ARN\"" <<<"$rendered"; then
    echo "Failed to inject management role ARN into $ROLE_POLICY_PATH." >&2
    exit 1
  fi
  printf '%s\n' "$rendered"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile|-p)
      PROFILE="${2:-}"
      if [[ -z "$PROFILE" ]]; then
        echo "Error: --profile requires a value." >&2
        exit 1
      fi
      shift 2
      ;;
    --role-name|-r)
      ROLE_NAME="${2:-}"
      if [[ -z "$ROLE_NAME" ]]; then
        echo "Error: --role-name requires a value." >&2
        exit 1
      fi
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd aws
require_cmd jq

if [[ ! -f "$TRUST_POLICY_PATH" ]]; then
  echo "Trust policy file not found: $TRUST_POLICY_PATH" >&2
  exit 1
fi

if [[ ! -f "$ROLE_POLICY_PATH" ]]; then
  echo "Management role policy file not found: $ROLE_POLICY_PATH" >&2
  exit 1
fi

if ! ACCOUNT_ID="$(aws sts get-caller-identity --profile "$PROFILE" --query 'Account' --output text 2>/dev/null)"; then
  echo "Failed to resolve account for profile '$PROFILE'. Check AWS credentials/profile setup." >&2
  exit 1
fi

resolve_external_id
TRUST_POLICY_DOCUMENT="$(build_trust_policy)"

echo "About to create/update Braintrust management role with:"
echo "  AWS profile : $PROFILE"
echo "  AWS account : $ACCOUNT_ID"
echo "  Role name   : $ROLE_NAME"
echo
read -r -p "Continue? Type 'yes' to proceed: " APPROVAL

if [[ "$APPROVAL" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

if aws iam get-role --profile "$PROFILE" --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Role '$ROLE_NAME' already exists. Updating trust policy..."
  aws iam update-assume-role-policy \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --policy-document "$TRUST_POLICY_DOCUMENT" \
    >/dev/null
  echo "Updating max session duration to 1 hour..."
  aws iam update-role \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --max-session-duration "$MAX_SESSION_DURATION_SECONDS" \
    >/dev/null
  MANAGEMENT_ROLE_ARN="$(aws iam get-role \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --query 'Role.Arn' \
    --output text)"
else
  echo "Creating role '$ROLE_NAME'..."
  MANAGEMENT_ROLE_ARN="$(aws iam create-role \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY_DOCUMENT" \
    --max-session-duration "$MAX_SESSION_DURATION_SECONDS" \
    --query 'Role.Arn' \
    --output text)"
fi

ROLE_POLICY_DOCUMENT="$(build_role_policy)"

echo "Applying inline permissions policy '$INLINE_POLICY_NAME'..."
aws iam put-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME" \
  --policy-document "$ROLE_POLICY_DOCUMENT" \
  >/dev/null

echo "Done. Role '$ROLE_NAME' is configured in account $ACCOUNT_ID."
echo "Role ARN: $MANAGEMENT_ROLE_ARN"
echo
echo "Share this External ID with Braintrust:"
echo "  $EXTERNAL_ID"
