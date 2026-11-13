#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRUST_POLICY_PATH="$SCRIPT_DIR/policies/management-role-trust-policy.json"
ROLE_POLICY_PATH="$SCRIPT_DIR/policies/management-role-policy.json"

ROLE_NAME="${ROLE_NAME:-BraintrustManagementRole}"
PROFILE="${AWS_PROFILE:-default}"
INLINE_POLICY_NAME="${INLINE_POLICY_NAME:-BraintrustManagementRolePolicy}"
EXTERNAL_ID=""
MAX_SESSION_DURATION_SECONDS=14400
POLICY_ONLY=false

usage() {
  cat <<'EOF'
Usage:
  bash managed-byoc/create-management-role.sh [--profile PROFILE] [--role-name ROLE_NAME] [--policy-only]

Options:
  --profile, -p    AWS profile to use (default: AWS_PROFILE env var, else "default")
  --role-name, -r  IAM role name to create or update (default: BraintrustManagementRole)
  --policy-only    Only replace the inline permissions policy on an existing role.
                   Leaves the trust policy, ExternalId and max session duration alone.
                   Shows a diff against the current policy before asking to continue.
  --help, -h       Show this help

Environment:
  AWS_PROFILE         Default profile if --profile is not provided
  ROLE_NAME           Default role name if --role-name is not provided
  INLINE_POLICY_NAME  Name for inline role policy (default: BraintrustManagementRolePolicy).
                      With --policy-only, this must name an existing inline policy on the role.
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
      --output json | jq -r '.Role.AssumeRolePolicyDocument | fromjson | .Statement[0].Condition.StringEquals."sts:ExternalId" // empty')"
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

put_inline_policy() {
  echo "Applying inline permissions policy '$INLINE_POLICY_NAME'..."
  aws iam put-role-policy \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --policy-name "$INLINE_POLICY_NAME" \
    --policy-document "file://$ROLE_POLICY_PATH" \
    >/dev/null
}

# Prints the output of a read-only AWS CLI call, or exits with the AWS error
# (for example AccessDenied, expired credentials or throttling).
aws_read() {
  local output error_file
  error_file="$(mktemp)"
  if ! output="$("$@" 2>"$error_file")"; then
    echo "AWS call failed: ${*:1:3}" >&2
    cat "$error_file" >&2
    rm -f "$error_file"
    exit 1
  fi
  rm -f "$error_file"
  printf '%s\n' "$output"
}

# Replaces the inline policy on an existing role and leaves the rest of the role alone.
# A full run rewrites the trust policy and max session duration, which would overwrite
# any customizations made to them.
update_policy_only() {
  local role_error policy_names current_policy current_policy_file new_policy_file

  if ! role_error="$(aws iam get-role --profile "$PROFILE" --role-name "$ROLE_NAME" 2>&1 >/dev/null)"; then
    if [[ "$role_error" == *NoSuchEntity* ]]; then
      echo "Role '$ROLE_NAME' does not exist. --policy-only only updates an existing role." >&2
    else
      echo "Failed to read role '$ROLE_NAME':" >&2
      echo "$role_error" >&2
    fi
    exit 1
  fi

  # put-role-policy adds a new inline policy when the name doesn't match, which would
  # leave the old policy attached beside the new one.
  policy_names="$(aws_read aws iam list-role-policies --profile "$PROFILE" --role-name "$ROLE_NAME" --output json)"
  if ! jq -e --arg name "$INLINE_POLICY_NAME" '.PolicyNames | index($name)' <<<"$policy_names" >/dev/null; then
    echo "Role '$ROLE_NAME' has no inline policy named '$INLINE_POLICY_NAME'." >&2
    echo "Inline policies on the role: $(jq -r '.PolicyNames | join(", ")' <<<"$policy_names")" >&2
    echo "Set INLINE_POLICY_NAME to the policy you applied earlier. Otherwise this would add a second inline policy." >&2
    exit 1
  fi

  current_policy="$(aws_read aws iam get-role-policy \
    --profile "$PROFILE" \
    --role-name "$ROLE_NAME" \
    --policy-name "$INLINE_POLICY_NAME" \
    --query PolicyDocument \
    --output json)"
  # Sort keys so the diff shows content changes, not formatting or key order.
  current_policy_file="$(mktemp)"
  new_policy_file="$(mktemp)"
  jq -S . <<<"$current_policy" >"$current_policy_file"
  jq -S . "$ROLE_POLICY_PATH" >"$new_policy_file"

  if diff -u --label "current ($INLINE_POLICY_NAME)" --label "new ($ROLE_POLICY_PATH)" \
    "$current_policy_file" "$new_policy_file"; then
    rm -f "$current_policy_file" "$new_policy_file"
    echo "The inline policy already matches. Nothing to update."
    exit 0
  fi
  rm -f "$current_policy_file" "$new_policy_file"

  echo
  echo "About to replace the inline policy on the existing Braintrust management role with:"
  echo "  AWS profile : $PROFILE"
  echo "  AWS account : $ACCOUNT_ID"
  echo "  Role name   : $ROLE_NAME"
  echo "  Policy name : $INLINE_POLICY_NAME"
  echo "The whole policy document is replaced. Review the diff above for customer edits that would be removed."
  echo "The trust policy, ExternalId and max session duration are not changed."
  echo
  read -r -p "Continue? Type 'yes' to proceed: " APPROVAL

  if [[ "$APPROVAL" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi

  put_inline_policy

  echo "Done. Inline policy '$INLINE_POLICY_NAME' is updated on role '$ROLE_NAME' in account $ACCOUNT_ID."
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
    --policy-only)
      POLICY_ONLY=true
      shift
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

if [[ "$POLICY_ONLY" == false && ! -f "$TRUST_POLICY_PATH" ]]; then
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

if [[ "$POLICY_ONLY" == true ]]; then
  update_policy_only
  exit 0
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
    --assume-role-policy-document "$TRUST_POLICY_DOCUMENT" \
    --max-session-duration "$MAX_SESSION_DURATION_SECONDS" \
    >/dev/null
fi

put_inline_policy

echo "Done. Role '$ROLE_NAME' is configured in account $ACCOUNT_ID."
echo "Role ARN: arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
echo
echo "Share this External ID with Braintrust:"
echo "  $EXTERNAL_ID"
