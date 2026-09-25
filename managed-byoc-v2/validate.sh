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
    -e 's|<MANAGED_RESOURCE_PREFIX>|bt-a-|g' \
    -e 's|<RUNTIME_BOUNDARY_ARN>|arn:aws:iam::111122223333:policy/braintrust-byoc/BraintrustRuntimeBoundary-review|g' \
    -e 's|<STATE_BUCKET_NAME>|customer-review-state|g' \
    -e 's|<OPERATION_LOG_BUCKET_NAME>|customer-review-operations|g' \
    -e 's|<BRAINTRUST_ARTIFACT_BUCKET_NAME>|braintrust-assets-us-east-1|g' \
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

if [[ "$package_dir" == "$source_dir" ]]; then
  if rg -n '<(BRAINSTORE_BUCKET_NAME|DATA_PLANE_KMS_KEY_ARN|RETAINED_RDS_SNAPSHOT_PREFIX)>' \
      "$policy_dir" "$guardrail_dir" -g '*.json'; then
    echo 'A policy still requires a post-creation data plane identifier.' >&2
    exit 1
  fi

  assert_scope() {
    local pattern="$1"
    local first="$2"
    local second="$3"
    local outside="$4"
    if [[ "$first" != $pattern || "$second" != $pattern || "$outside" == $pattern ]]; then
      echo "Managed prefix pattern does not isolate two sample data planes: $pattern" >&2
      exit 1
    fi
  }

  boundary="$temporary_dir/deployment-permissions-boundary.json"
  retained="$temporary_dir/customer-retained-data-service-control-policy.json"
  infrastructure="$temporary_dir/deployment-infrastructure-policy.json"

  for file in "$boundary" "$retained"; do
    sid=ProtectRetainedBrainstoreData
    [[ "$file" == "$boundary" ]] && sid=ProtectBrainstoreData
    pattern="$(jq -r --arg sid "$sid" '.Statement[] | select(.Sid == $sid) | .Resource[0]' "$file")"
    assert_scope "$pattern" \
      'arn:aws:s3:::bt-a-one-brainstore-1234' \
      'arn:aws:s3:::bt-a-two-brainstore-5678' \
      'arn:aws:s3:::bt-b-one-brainstore-1234'

    sid=ProtectRetainedDatabaseSnapshots
    [[ "$file" == "$boundary" ]] && sid=ProtectRDSSnapshots
    pattern="$(jq -r --arg sid "$sid" '.Statement[] | select(.Sid == $sid) | .Resource' "$file")"
    assert_scope "$pattern" \
      'arn:aws:rds:us-east-1:111122223333:snapshot:bt-a-one-main-final-snapshot-1234' \
      'arn:aws:rds:us-east-1:111122223333:snapshot:bt-a-two-main-final-snapshot-5678' \
      'arn:aws:rds:us-east-1:111122223333:snapshot:bt-b-one-main-final-snapshot-1234'
  done

  pattern="$(jq -r '.Statement[] | select(.Sid == "DenyOtherInvocations") | .NotResource[0]' "$boundary")"
  assert_scope "$pattern" \
    'arn:aws:lambda:us-east-1:111122223333:function:bt-a-one-MigrateDatabaseFunction' \
    'arn:aws:lambda:us-east-1:111122223333:function:bt-a-two-MigrateDatabaseFunction' \
    'arn:aws:lambda:us-east-1:111122223333:function:bt-b-one-MigrateDatabaseFunction'

  pattern="$(jq -r '.Statement[] | select(.Sid == "ManagePrefixedParameters") | .Resource[1]' "$infrastructure")"
  assert_scope "$pattern" \
    'arn:aws:ssm:us-east-1:111122223333:parameter/braintrust/bt-a-one/ai-proxy-url' \
    'arn:aws:ssm:us-east-1:111122223333:parameter/braintrust/bt-a-two/ecs-api-url' \
    'arn:aws:ssm:us-east-1:111122223333:parameter/braintrust/bt-b-one/ai-proxy-url'

  jq -e '.Statement[] | select(.Sid == "ProtectKeysAndAliases") |
    .Resource | index("arn:aws:kms:us-east-1:111122223333:key/*") != null' "$boundary" >/dev/null
  jq -e '.Statement[] | select(.Sid == "ProtectRetainedDataPlaneKey") |
    .Resource | index("arn:aws:kms:us-east-1:111122223333:key/*") != null' "$retained" >/dev/null

  access_guardrail="$temporary_dir/customer-service-control-policy.json"
  jq -e '.Statement[] | select(.Sid == "DenyDeploymentDecryptOutsideBootstrapAndManagedKeys") |
    .Condition."StringNotLikeIfExists"."aws:ResourceTag/BraintrustDeploymentName" == "bt-a-*"' \
    "$access_guardrail" >/dev/null
  jq -e '.Statement[] | select(.Sid == "KeepManagedKmsOwnershipTag") |
    .Condition."ForAnyValue:StringEquals"."aws:TagKeys" == "BraintrustDeploymentName"' \
    "$access_guardrail" >/dev/null
  for action in logs:CreateExportTask logs:PutSubscriptionFilter logs:CreateDelivery; do
    jq -e --arg action "$action" '.Statement[] | select(.Sid == "DenyDeploymentLogRoutingAndExport") |
      .Action | index($action) != null' "$access_guardrail" >/dev/null
  done
  if jq -e '[.Statement[] | select(.Sid == "ManageDataPlaneServices") | .Action[]] |
      any(. == "dynamodb:*" or . == "eks:*" or . == "ec2-instance-connect:*")' \
      "$infrastructure" >/dev/null; then
    echo 'Unused broad deployment actions returned.' >&2
    exit 1
  fi
  echo 'Multi-data-plane naming and retained-key scope checks passed.'
fi

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
