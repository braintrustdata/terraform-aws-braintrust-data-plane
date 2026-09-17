#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_dir="${1:-$source_dir}"
policy_dir="$package_dir/policies"
trust_dir="$package_dir/trust-policies"
guardrail_dir="$package_dir/guardrails"

managed_policy_limit=6144
trust_policy_limit=2048
scp_limit=10240

command -v jq >/dev/null
command -v rg >/dev/null

policy_files=("$policy_dir"/*.json)
trust_files=("$trust_dir"/*.json)
scp_files=("$guardrail_dir"/*service-control-policy.json)

for file in "${policy_files[@]}" "${scp_files[@]}" "${trust_files[@]}"; do
  jq empty "$file"
done

measure_policy() {
  local file="$1"
  local limit="$2"
  local label
  local size

  label="$(basename "$file")"
  size="$(jq -c . "$file" | tr -d '\n' | wc -c | tr -d ' ')"
  if (( size > limit )); then
    echo "${label} is ${size} characters; limit is ${limit}" >&2
    exit 1
  fi
  printf '%-44s %5s / %s\n' "$label" "$size" "$limit"
}

for file in "${policy_files[@]}"; do
  measure_policy "$file" "$managed_policy_limit"
done
for file in "${scp_files[@]}"; do
  measure_policy "$file" "$scp_limit"
done
for file in "${trust_files[@]}"; do
  measure_policy "$file" "$trust_policy_limit"
done

temporary_dir="$(mktemp -d)"
trap 'find "$temporary_dir" -type f -delete; rmdir "$temporary_dir"' EXIT

render_policy() {
  local input="$1"
  local output="$2"

  sed \
    -e 's|<AWS_PARTITION>|aws|g' \
    -e 's|<AWS_ACCOUNT_ID>|111122223333|g' \
    -e 's|<ACCOUNT_ID>|111122223333|g' \
    -e 's|<AWS_REGION>|us-east-1|g' \
    -e 's|<BOOTSTRAP_NAME>|review|g' \
    -e 's|<MANAGED_RESOURCE_PREFIX>|braintrust|g' \
    -e 's|<RUNTIME_BOUNDARY_ARN>|arn:aws:iam::111122223333:policy/braintrust-byoc/BraintrustRuntimeBoundary-review|g' \
    -e 's|<STATE_BUCKET_NAME>|customer-review-state|g' \
    -e 's|<OPERATION_LOG_BUCKET_NAME>|customer-review-operations|g' \
    -e 's|<BRAINSTORE_BUCKET_NAME>|braintrust-review-brainstore|g' \
    -e 's|<DATA_PLANE_KMS_KEY_ARN>|arn:aws:kms:us-east-1:111122223333:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee|g' \
    -e 's|<RETAINED_RDS_SNAPSHOT_PREFIX>|braintrust-main-final-snapshot-|g' \
    -e 's|<LICENSE_SECRET_ARN>|arn:aws:secretsmanager:us-east-1:111122223333:secret:braintrust-license-review|g' \
    -e 's|<LICENSE_SECRET_KMS_KEY_ARN>|arn:aws:kms:us-east-1:111122223333:key/11111111-2222-3333-4444-555555555555|g' \
    -e 's|<STATE_KMS_KEY_ARN>|arn:aws:kms:us-east-1:111122223333:key/22222222-2222-3333-4444-555555555555|g' \
    -e 's|<OPERATION_LOG_KMS_KEY_ARN>|arn:aws:kms:us-east-1:111122223333:key/33333333-2222-3333-4444-555555555555|g' \
    -e 's|<BRAINTRUST_DEPLOYMENT_PRINCIPAL_ARN>|arn:aws:iam::444455556666:role/braintrust-deployment|g' \
    -e 's|<BRAINTRUST_HUMAN_PRINCIPAL_ARN>|arn:aws:iam::444455556666:role/braintrust-human|g' \
    -e 's|<UNIQUE_EXTERNAL_ID>|review-only-external-id|g' \
    "$input" >"$output"
}

if [[ $# -gt 0 ]] && rg -n '<[A-Z_]+>' "$policy_dir" "$trust_dir" "$guardrail_dir" -g '*.json'; then
  echo 'The supplied rendered package still contains placeholders.' >&2
  exit 1
fi

echo 'Rendered-size checks (sample values unless a rendered package was supplied):'
for file in "${policy_files[@]}" "${scp_files[@]}" "${trust_files[@]}"; do
  rendered="$temporary_dir/$(basename "$file")"
  render_policy "$file" "$rendered"
  if rg -n '<[A-Z_]+>' "$rendered"; then
    echo 'A policy placeholder has no sample rendering.' >&2
    exit 1
  fi
  limit="$managed_policy_limit"
  [[ "$file" == "$guardrail_dir/"* ]] && limit="$scp_limit"
  [[ "$file" == "$trust_dir/"* ]] && limit="$trust_policy_limit"
  measure_policy "$rendered" "$limit"
done

if [[ "${VALIDATE_WITH_AWS:-0}" != "1" ]]; then
  exit 0
fi
command -v aws >/dev/null

validate_with_access_analyzer() {
  local file="$1"
  local policy_type="$2"
  local resource_type="${3:-}"
  local rendered="$temporary_dir/$(basename "$file")"
  local findings

  render_policy "$file" "$rendered"
  if [[ -n "$resource_type" ]]; then
    findings="$(aws accessanalyzer validate-policy \
      --policy-type "$policy_type" \
      --validate-policy-resource-type "$resource_type" \
      --policy-document "file://${rendered}" \
      | jq -c '[.findings[] | select(.findingType == "ERROR" or .findingType == "SECURITY_WARNING")]')"
  else
    findings="$(aws accessanalyzer validate-policy \
      --policy-type "$policy_type" \
      --policy-document "file://${rendered}" \
      | jq -c '[.findings[] | select(.findingType == "ERROR" or .findingType == "SECURITY_WARNING")]')"
  fi

  if [[ "$findings" != "[]" ]]; then
    echo "Access Analyzer findings for $(basename "$file"): $findings" >&2
    exit 1
  fi
  echo "Access Analyzer passed: $(basename "$file")"
}

for file in "${policy_files[@]}"; do
  validate_with_access_analyzer "$file" IDENTITY_POLICY
done
for file in "${scp_files[@]}"; do
  validate_with_access_analyzer "$file" SERVICE_CONTROL_POLICY
done
for file in "${trust_files[@]}"; do
  validate_with_access_analyzer \
    "$file" RESOURCE_POLICY AWS::IAM::AssumeRolePolicyDocument
done
