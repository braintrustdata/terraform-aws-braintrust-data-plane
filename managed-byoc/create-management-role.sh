#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRUST_POLICY_PATH="$SCRIPT_DIR/policies/management-role-trust-policy.json"
ROLE_POLICY_PATH="$SCRIPT_DIR/policies/management-role-policy.json"

ROLE_NAME="${ROLE_NAME:-BraintrustManagementRole}"
PROFILE="${AWS_PROFILE:-default}"
INLINE_POLICY_NAME="${INLINE_POLICY_NAME:-BraintrustManagementRolePolicy}"
MAX_SESSION_DURATION_SECONDS=14400

usage() {
  cat <<'EOF'
Usage:
  bash managed-byoc/create-management-role.sh [--profile PROFILE] [--role-name ROLE_NAME]

Options:
  --profile, -p    AWS profile to use (default: AWS_PROFILE env var, else "default")
  --role-name, -r  IAM role name to create (default: BraintrustManagementRole)
  --help, -h       Show this help

Environment:
  AWS_PROFILE      Default profile if --profile is not provided
  ROLE_NAME        Default role name if --role-name is not provided
  INLINE_POLICY_NAME  Name for inline role policy (default: BraintrustManagementRolePolicy)
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
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
    --policy-document "file://$TRUST_POLICY_PATH" \
    >/dev/null
  echo "Updating max session duration to 4 hours..."
  aws iam update-role \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --max-session-duration "$MAX_SESSION_DURATION_SECONDS" \
    >/dev/null
else
  echo "Creating role '$ROLE_NAME'..."
  aws iam create-role \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://$TRUST_POLICY_PATH" \
    --max-session-duration "$MAX_SESSION_DURATION_SECONDS" \
    >/dev/null
fi

echo "Applying inline permissions policy '$INLINE_POLICY_NAME'..."
aws iam put-role-policy \
  --profile "$PROFILE" \
  --role-name "$ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME" \
  --policy-document "file://$ROLE_POLICY_PATH" \
  >/dev/null

echo "Done. Role '$ROLE_NAME' is configured in account $ACCOUNT_ID."
echo "Role ARN: arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
