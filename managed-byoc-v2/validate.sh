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

# Placeholder text is not an AWS policy. Enforce size limits after rendering,
# not against the longer placeholder names in the source templates.

temporary_dir="$(mktemp -d)"
trap 'find "$temporary_dir" -type f -delete; rmdir "$temporary_dir"' EXIT

render_policy() {
  local input="$1"
  local output="$2"
  local sample_region=us-east-1 sample_bootstrap=review sample_prefix=bt-a-
  local sample_state=customer-review-state sample_operations=customer-review-operations
  local sample_artifacts=braintrust-assets-us-east-1
  local sample_license=arn:aws:secretsmanager:us-east-1:111122223333:secret:braintrust-license-review
  local sample_principal=arn:aws:iam::444455556666:role/braintrust-human
  local sample_external_id=review-only-external-id
  if [[ "${3:-sample}" == maximum ]]; then
    sample_region=ap-southeast-5
    sample_bootstrap=bbbbbbbbbbbbbbbb
    sample_prefix=ppppppp-
    sample_state="$(printf '%63s' '' | tr ' ' s)"
    sample_operations="$(printf '%63s' '' | tr ' ' o)"
    sample_artifacts="$(printf '%63s' '' | tr ' ' a)"
    sample_license="arn:aws:secretsmanager:${sample_region}:111122223333:secret:$(printf '%63s' '' | tr ' ' l)-ABC123"
    sample_principal="arn:aws:iam::444455556666:role/$(printf '%223s' '' | tr ' ' p)/role"
    sample_external_id="$(printf '%128s' '' | tr ' ' e)"
  fi

  sed \
    -e 's|<AWS_PARTITION>|aws|g' \
    -e 's|<AWS_ACCOUNT_ID>|111122223333|g' \
    -e "s|<AWS_REGION>|${sample_region}|g" \
    -e "s|<BOOTSTRAP_NAME>|${sample_bootstrap}|g" \
    -e "s|<MANAGED_RESOURCE_PREFIX>|${sample_prefix}|g" \
    -e "s|<RUNTIME_BOUNDARY_ARN>|arn:aws:iam::111122223333:policy/braintrust-byoc/BraintrustRuntimeBoundary-${sample_bootstrap}|g" \
    -e "s|<DIAGNOSTICS_ROLE_ARN>|arn:aws:iam::111122223333:role/braintrust-byoc/BraintrustDiagnosticsRole-${sample_bootstrap}|g" \
    -e "s|<DIAGNOSTICS_POLICY_ARN>|arn:aws:iam::111122223333:policy/braintrust-byoc/BraintrustDiagnosticsPolicy-${sample_bootstrap}|g" \
    -e 's|<DIAGNOSTICS_ROLE_ID>|AROADIAGNOSTICSEXAMPLE|g' \
    -e "s|<STATE_BUCKET_NAME>|${sample_state}|g" \
    -e "s|<OPERATION_LOG_BUCKET_NAME>|${sample_operations}|g" \
    -e "s|<BRAINTRUST_ARTIFACT_BUCKET_NAME>|${sample_artifacts}|g" \
    -e "s|<LICENSE_SECRET_ARN>|${sample_license}|g" \
    -e "s|<LICENSE_SECRET_KMS_KEY_ARN>|arn:aws:kms:${sample_region}:111122223333:key/11111111-2222-3333-4444-555555555555|g" \
    -e "s|<STATE_KMS_KEY_ARN>|arn:aws:kms:${sample_region}:111122223333:key/22222222-2222-3333-4444-555555555555|g" \
    -e "s|<OPERATION_LOG_KMS_KEY_ARN>|arn:aws:kms:${sample_region}:111122223333:key/33333333-2222-3333-4444-555555555555|g" \
    -e "s|<BRAINTRUST_DEPLOYMENT_PRINCIPAL_ARN>|${sample_principal}|g" \
    -e "s|<BRAINTRUST_HUMAN_PRINCIPAL_ARN>|${sample_principal}|g" \
    -e "s|<UNIQUE_EXTERNAL_ID>|${sample_external_id}|g" \
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
  if [[ "$package_dir" == "$source_dir" ]]; then
    render_policy "$file" "$temporary_dir/maximum-$(basename "$file")" maximum
    measure_policy "$temporary_dir/maximum-$(basename "$file")" "$limit"
  fi
done

check_rendered_names() {
  local fixture="$1" role policy account bootstrap prefix role_pattern runtime_boundary
  local state_resource state_bucket operation_resource operation_bucket license principal external_id bucket trust file
  local activation_file="$temporary_dir/${fixture}deployment-diagnostics-policy.json"
  local infrastructure_file="$temporary_dir/${fixture}deployment-infrastructure-policy.json"
  local data_file="$temporary_dir/${fixture}deployment-data-policy.json"
  role="$(jq -er '.Statement[] | select(.Sid == "ActivatePredefinedDiagnostics") | .Resource' "$activation_file")"
  role_pattern='^arn:aws:iam::([0-9]{12}):role/braintrust-byoc/BraintrustDiagnosticsRole-([a-z0-9][a-z0-9-]{0,15})$'
  if [[ ! "$role" =~ $role_pattern ]]; then
    echo 'Diagnostics role must use the protected IAM path and a bootstrap identifier of at most 16 characters.' >&2
    exit 1
  fi
  account="${BASH_REMATCH[1]}"
  bootstrap="${BASH_REMATCH[2]}"
  policy="$(jq -er '.Statement[] | select(.Sid == "ActivatePredefinedDiagnostics") | .Condition.ArnEquals."iam:PolicyARN"' "$activation_file")"
  runtime_boundary="arn:aws:iam::${account}:policy/braintrust-byoc/BraintrustRuntimeBoundary-${bootstrap}"
  [[ "$policy" == "arn:aws:iam::${account}:policy/braintrust-byoc/BraintrustDiagnosticsPolicy-${bootstrap}" ]]
  jq -e --arg boundary "$runtime_boundary" '[.Statement[] |
    select(.Sid == "CreateBoundedRoles" or .Sid == "SetRuntimeBoundary") |
    .Condition.ArnEquals."iam:PermissionsBoundary" == $boundary] == [true,true]' "$infrastructure_file" >/dev/null
  jq -e --arg boundary "$runtime_boundary" '.Statement[] | select(.Sid == "RequireRuntimeBoundary") |
    .Condition.ArnNotEquals."iam:PermissionsBoundary" == $boundary' \
    "$temporary_dir/${fixture}customer-service-control-policy.json" >/dev/null
  for file in deployment-permissions-boundary.json customer-service-control-policy.json; do
    jq -e --arg role "$role" --arg policy "$policy" '
      ([.Statement[] | select(.Sid == "DenyOtherBootstrapAttachments") |
        .Condition.ArnNotEquals."iam:PolicyARN" == $policy] == [true]) and
      ([.Statement[] | select(.Sid == "DenyDiagnosticsPolicyElsewhere") |
        .NotResource == $role and .Condition.ArnEquals."iam:PolicyARN" == $policy] == [true])' \
      "$temporary_dir/${fixture}${file}" >/dev/null
  done
  prefix="$(jq -er '.Statement[] | select(.Sid == "ManagePrefixedRoles") | .Resource' "$infrastructure_file")"
  role_pattern="^arn:aws:iam::${account}:role/([a-z0-9][a-z0-9-]{0,6}-)\\*$"
  if [[ ! "$prefix" =~ $role_pattern ]]; then
    echo 'Runtime IAM prefix must use the root path, end in a hyphen, and be 2–8 characters.' >&2
    exit 1
  fi
  prefix="${BASH_REMATCH[1]}"
  state_resource="$(jq -er '.Statement[] | select(.Sid == "ReadAndWriteTerraformState") | .Resource' "$data_file")"
  state_bucket="${state_resource#arn:aws:s3:::}"
  state_bucket="${state_bucket%%/*}"
  operation_resource="$(jq -er '.Statement[] | select(.Sid == "WriteOperationLogs") | .Resource' "$data_file")"
  operation_bucket="${operation_resource#arn:aws:s3:::}"
  operation_bucket="${operation_bucket%%/*}"
  [[ "$state_resource" == "arn:aws:s3:::${state_bucket}/braintrust-byoc/${bootstrap}/*" ]]
  [[ "$operation_resource" == "arn:aws:s3:::${operation_bucket}/braintrust-byoc/operations/${bootstrap}/*" ]]
  for bucket in "$state_bucket" "$operation_bucket"; do
    if [[ "$bucket" == "$prefix"* || ${#bucket} -gt 63 || ${#bucket} -lt 3 ]]; then
      echo 'Bootstrap buckets must be outside the runtime prefix and use valid S3 name lengths.' >&2
      exit 1
    fi
  done
  [[ "$state_bucket" != "$operation_bucket" ]]
  license="$(jq -er '.Statement[] | select(.Sid == "ReadLicenseSecret") | .Resource' "$data_file")"
  [[ ${#license} -le 128 && "$license" != *'*'* && "$license" != *'?'* ]]
  for trust in deployment-role-trust-policy.json human-role-trust-policy.json; do
    principal="$(jq -er '.Statement[0].Principal.AWS' "$temporary_dir/${fixture}${trust}")"
    role_pattern='^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9_+=,.@/-]+$'
    [[ "$principal" =~ $role_pattern && ${#principal} -le 256 ]]
  done
  external_id="$(jq -er '.Statement[0].Condition.StringEquals."sts:ExternalId"' "$temporary_dir/${fixture}deployment-role-trust-policy.json")"
  [[ ${#external_id} -ge 2 && ${#external_id} -le 128 ]]
  for file in "${policy_files[@]}" "${scp_files[@]}"; do
    jq -e --arg account "$account" --arg bootstrap "$bootstrap" '
      [.. | strings | select(startswith("arn:aws:iam::" + $account + ":role/braintrust-byoc/Braintrust"))] |
      all(endswith("Role-" + $bootstrap))' "$temporary_dir/${fixture}$(basename "$file")" >/dev/null
  done
}

check_rendered_names ''
if [[ "$package_dir" == "$source_dir" ]]; then
  check_rendered_names maximum-
fi
echo 'Bootstrap naming, protected IAM paths, and input length checks passed.'

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
    [[ "$file" == "$boundary" ]] && sid=ProtectRetainedData
    pattern="$(jq -r --arg sid "$sid" '.Statement[] | select(.Sid == $sid) | .Resource[0]' "$file")"
    assert_scope "$pattern" \
      'arn:aws:s3:::bt-a-one-brainstore-1234' \
      'arn:aws:s3:::bt-a-two-brainstore-5678' \
      'arn:aws:s3:::bt-b-one-brainstore-1234'

    sid=ProtectRetainedDatabaseSnapshots
    [[ "$file" == "$boundary" ]] && sid=ProtectRetainedData
    pattern="$(jq -r --arg sid "$sid" '.Statement[] | select(.Sid == $sid) | .Resource |
      if type == "array" then .[] | select(contains(":snapshot:")) else . end' "$file")"
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

  jq -e '.Statement[] | select(.Sid == "ProtectRetainedData") |
    .Resource | index("arn:aws:kms:us-east-1:111122223333:key/*") != null' "$boundary" >/dev/null
  jq -e '.Statement[] | select(.Sid == "ProtectRetainedDataPlaneKey") |
    .Resource | index("arn:aws:kms:us-east-1:111122223333:key/*") != null' "$retained" >/dev/null

  access_guardrail="$temporary_dir/customer-service-control-policy.json"
  jq -e '[.Statement[] | select(.Sid == "DenyAccountAndOrganizationAdministration") |
    .Effect == "Deny" and .Resource == "*" and
    (has("Condition") | not) and (has("NotAction") | not) and
    ([.Action[] | select(startswith("s3:"))] == ["s3:PutAccountPublicAccessBlock"])] == [true]' \
    "$access_guardrail" >/dev/null
  jq -e '[.Statement[] | select(.Sid == "DenyDeploymentRoleActionsOutsidePrefix") |
    .Effect == "Deny" and
    (.Action | sort) == (["iam:CreateRole", "iam:PassRole"] | sort) and
    .NotResource == "arn:aws:iam::111122223333:role/bt-a-*" and
    .Condition == {"ArnEquals": {"aws:PrincipalArn":
      "arn:aws:iam::111122223333:role/braintrust-byoc/BraintrustDeploymentRole-review"}}] == [true]' \
    "$access_guardrail" >/dev/null
  for action in s3:PutBucketPolicy s3:PutBucketPublicAccessBlock \
      s3:GetBucketOwnershipControls s3:PutBucketOwnershipControls; do
    jq -e --arg action "$action" '.Statement[] | select(.Sid == "ManagePrefixedBuckets") |
      .Effect == "Allow" and .Resource == "arn:aws:s3:::bt-a-*" and
      (.Action | index($action) != null)' \
      "$temporary_dir/deployment-data-policy.json" >/dev/null
  done
  echo 'Account-level S3 protection, scoped ownership controls, and preserved bucket management checks passed (static checks only).'
  jq -e '.Statement[] | select(.Sid == "RestrictDeploymentDecryptKeys") |
    .Condition."StringNotLikeIfExists"."aws:ResourceTag/BraintrustDeploymentName" == "bt-a-*"' \
    "$access_guardrail" >/dev/null
  jq -e '.Statement[] | select(.Sid == "KeepManagedKmsOwnershipTag") |
    .Condition."ForAnyValue:StringEquals"."aws:TagKeys" == "BraintrustDeploymentName"' \
    "$access_guardrail" >/dev/null
  jq -e '[.Statement[] | select(.Sid == "DenyDeploymentLogRoutingAndInteractiveAccess") |
    .Effect == "Deny" and .Resource == "*" and
    .Condition == {"ArnEquals": {"aws:PrincipalArn":
      "arn:aws:iam::111122223333:role/braintrust-byoc/BraintrustDeploymentRole-review"}} and
    (.Action | sort) == ([
      "logs:AssociateSourceToS3TableIntegration", "logs:CreateDelivery", "logs:CreateExportTask",
      "logs:PutAccountPolicy", "logs:PutDeliveryDestination", "logs:PutDeliveryDestinationPolicy",
      "logs:PutDeliverySource", "logs:PutDestination", "logs:PutDestinationPolicy",
      "logs:PutIntegration", "logs:PutResourcePolicy", "logs:PutSubscriptionFilter",
      "logs:PutSyslogConfiguration", "logs:UpdateDeliveryConfiguration",
      "ec2-instance-connect:OpenTunnel", "ec2-instance-connect:SendSSHPublicKey",
      "ecs:ExecuteCommand", "eks:AccessKubernetesApi", "ssm:SendCommand",
      "ssm:StartSession", "sts:AssumeRole"] | sort)] == [true]' \
    "$access_guardrail" >/dev/null
  if jq -e '[.Statement[] | select(.Sid == "ManageDataPlaneServices") | .Action[]] |
      any(. == "dynamodb:*" or . == "eks:*" or . == "ec2-instance-connect:*")' \
      "$infrastructure" >/dev/null; then
    echo 'Unused broad deployment actions returned.' >&2
    exit 1
  fi
  echo 'Multi-data-plane naming and retained-key scope checks passed.'

  runtime="$temporary_dir/runtime-permissions-boundary.json"
  jq -e '[.Statement[] | select(.Sid == "DenyBucketAccessAdministration") |
    .Effect == "Deny" and .Resource == "*" and
    (has("Condition") | not) and (has("NotAction") | not) and
    (.Action | sort) == (["s3:DeleteBucketPolicy", "s3:PutBucketAcl",
      "s3:PutBucketPolicy", "s3:PutBucketPublicAccessBlock"] | sort)] == [true]' \
    "$runtime" >/dev/null
  jq -e '[.Statement[] | select(.Sid == "AllowOnlyWorkloadPolicyPermissions") |
    .Effect == "Allow" and .NotAction == "iam:*" and .Resource == "*"] == [true]' \
    "$runtime" >/dev/null
  jq -e '[.Statement[] | select(.Effect == "Allow") | .Action |
    if type == "array" then .[] else . end] | index("s3:PutBucketAcl") == null' \
    "$temporary_dir/deployment-data-policy.json" >/dev/null
  echo 'Runtime bucket administration denial and unused deployment ACL removal checks passed (static checks only).'
  jq -e '.Statement[] | select(.Sid == "DenyWorkloadInitiatedInteractiveAccess") |
    .Effect == "Deny" and .Resource == "*" and
    (.Action | sort) == (["ssm:StartSession", "ssm:SendCommand",
      "ecs:ExecuteCommand", "ec2-instance-connect:*"] | sort)' "$runtime" >/dev/null
  jq -e '.Statement[] | select(.Sid == "DenyOtherRuntimeRoleAssumptions") |
    .Effect == "Deny" and .Action == "sts:AssumeRole" and
    (.NotResource | sort) == ([
      "arn:aws:iam::111122223333:role/bt-a-*-QuarantineInvokeRole",
      "arn:aws:iam::111122223333:role/bt-a-*-AIProxyInvokeRole"] | sort)' "$runtime" >/dev/null
  jq -e '.Statement[] | select(.Sid == "RestrictInternalInvokeCallers") |
    .Effect == "Deny" and .Condition.ArnNotLike."aws:PrincipalArn" ==
    "arn:aws:iam::111122223333:role/bt-a-*-APIHandlerRole"' "$runtime" >/dev/null
  for target in QuarantineInvokeRole AIProxyInvokeRole; do
    pattern="arn:aws:iam::111122223333:role/bt-a-*-${target}"
    assert_scope "$pattern" "arn:aws:iam::111122223333:role/bt-a-one-${target}" \
      "arn:aws:iam::111122223333:role/bt-a-two-${target}" \
      "arn:aws:iam::444455556666:role/bt-a-one-${target}"
  done
  for file in "$boundary" "$retained" "$temporary_dir/observer-policy.json"; do
    for action in cloudwatch:PutInsightRule cloudwatch:PutManagedInsightRules cloudwatch:GetInsightRuleReport \
        logs:CreateLogAnomalyDetector logs:ListAnomalies logs:GetLookupTable; do
      jq -e --arg action "$action" '[.Statement[] | select(.Effect == "Deny") | .Action |
        if type == "array" then .[] else . end] | index($action) != null' "$file" >/dev/null
    done
  done
  for action in s3:GetBucketAbac s3:PutBucketAbac s3:TagResource s3:UntagResource s3:ListTagsForResource; do
    jq -e --arg action "$action" '.Statement[] | select(.Sid == "ManagePrefixedBuckets") |
      .Resource == "arn:aws:s3:::bt-a-*" and (.Action | index($action) != null)' \
      "$temporary_dir/deployment-data-policy.json" >/dev/null
  done
  echo 'Internal invocation, log-content denial, and S3 ABAC scope checks passed.'

  diagnostics="$temporary_dir/diagnostics-policy.json"
  activation="$temporary_dir/deployment-diagnostics-policy.json"
  eks="$temporary_dir/deployment-eks-policy.json"
  diagnostic_guardrail="$temporary_dir/customer-diagnostics-service-control-policy.json"
  diagnostic_role='arn:aws:iam::111122223333:role/braintrust-byoc/BraintrustDiagnosticsRole-review'
  diagnostic_policy='arn:aws:iam::111122223333:policy/braintrust-byoc/BraintrustDiagnosticsPolicy-review'

  jq -e --arg role "$diagnostic_role" --arg policy "$diagnostic_policy" '
    .Statement[] | select(.Sid == "ActivatePredefinedDiagnostics") |
    .Effect == "Allow" and .Resource == $role and
    (.Action | sort) == (["iam:AttachRolePolicy", "iam:DetachRolePolicy"] | sort) and
    .Condition.ArnEquals."iam:PolicyARN" == $policy' "$activation" >/dev/null
  for file in "$boundary" "$access_guardrail"; do
    jq -e --arg role "$diagnostic_role" --arg policy "$diagnostic_policy" '
      ([.Statement[] | select(.Sid == "ProtectBootstrapIam") |
        .Effect == "Deny" and
        (.NotAction | sort) == (["iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:GetRole", "iam:ListAttachedRolePolicies", "iam:GetPolicy", "iam:GetPolicyVersion"] | sort)] == [true]) and
      ([.Statement[] | select(.Sid == "DenyOtherBootstrapAttachments") |
        .Effect == "Deny" and .Condition.ArnNotEquals."iam:PolicyARN" == $policy] == [true]) and
      ([.Statement[] | select(.Sid == "DenyDiagnosticsPolicyElsewhere") |
        .Effect == "Deny" and .NotResource == $role and
        .Condition.ArnEquals."iam:PolicyARN" == $policy] == [true])' "$file" >/dev/null
  done
  jq -e '.Statement[] | select(.Sid == "CloseDiagnosticSessions") |
    .Condition.StringLike."ssm:resourceTag/aws:ssmmessages:session-id" == "AROADIAGNOSTICSEXAMPLE:*"' \
    "$activation" >/dev/null
  jq -e '.Statement[] | select(.Sid == "StartBrainstoreShell") |
    .Condition.Bool."ssm:SessionDocumentAccessCheck" == "true" and
    .Condition.StringLike."ssm:resourceTag/BraintrustDeploymentName" == "bt-a-*" and
    (.Condition.StringEquals."ssm:resourceTag/BrainstoreRole" | length) == 4' "$diagnostics" >/dev/null
  jq -e '.Statement[] | select(.Sid == "UseLoggedShellDocument") |
    .Resource == "arn:aws:ssm:us-east-1:111122223333:document/BraintrustDiagnosticsShell-review"' \
    "$diagnostics" >/dev/null
  jq -e '.Statement[] | select(.Sid == "ManageOwnSessions") |
    .Condition.StringEquals."ssm:resourceTag/aws:ssmmessages:session-id" == "${aws:userid}"' \
    "$diagnostics" >/dev/null
  for action in 'iam:*' sts:AssumeRole ssm:SendCommand 's3:*' secretsmanager:GetSecretValue kms:Decrypt; do
    jq -e --arg action "$action" '.Statement[] | select(.Sid == "DenyDirectDataAndAlternateAccess") |
      .Action | index($action) != null' "$diagnostics" >/dev/null
  done
  jq -e '[.Statement[] | select(.Effect == "Allow") | .Action | if type == "array" then .[] else . end] |
    all(. != "ssm:*" and . != "ssm:SendCommand" and . != "iam:*" and . != "eks:*")' "$diagnostics" >/dev/null
  jq -e '[.Statement[] | select(.Sid | startswith("Create") and endswith("ClusterEntry")) |
    .Condition.StringEquals."eks:accessEntryType" == "STANDARD" and
    .Condition.Null."eks:kubernetesGroups" == "false" and
    .Condition.Null."eks:username" == "true" and
    (.Condition."ForAllValues:StringEquals"."eks:kubernetesGroups" | length) == 1] == [true,true,true]' \
    "$eks" >/dev/null
  jq -e '[.Statement[].Action | if type == "array" then .[] else . end] |
    all(. != "eks:*" and . != "eks:UpdateAccessEntry" and . != "eks:AssociateAccessPolicy")' "$eks" >/dev/null
  jq -e '.Statement[] | select(.Sid == "ManageFixedEntryMetadata") |
    (.Condition.StringEquals."eks:principalArn" | length) == 3 and
    (.Action | index("eks:TagResource") != null and index("eks:UntagResource") != null and
      index("eks:DescribeAccessEntry") != null and index("eks:ListTagsForResource") == null)' "$eks" >/dev/null
  jq -e '[.Statement[] | select(.Effect == "Allow" and .Resource == "*") | .Action |
    if type == "array" then .[] else . end] | index("eks:DescribeCluster") == null' "$infrastructure" >/dev/null
  if rg -q 'BraintrustDiagnosticsRole|braintrust:diagnostics' "$eks"; then
    echo 'EKS preparation must not create standing Diagnostics authorization.' >&2
    exit 1
  fi
  for sid in ProtectDiagnosticSessionDocument ProtectDiagnosticTranscripts; do
    jq -e --arg sid "$sid" '.Statement[] | select(.Sid == $sid) |
      .Effect == "Deny" and (.Condition.ArnLike."aws:PrincipalArn" | length) == 2' \
      "$diagnostic_guardrail" >/dev/null
  done
  jq -e '.Statement[] | select(.Sid == "RestrictEcsClusterUpdates") |
    .Effect == "Deny" and .Action == "ecs:UpdateCluster" and
    .Resource == "arn:aws:ecs:us-east-1:111122223333:cluster/bt-a-*" and
    (.Condition.ArnLike."aws:PrincipalArn" | sort) == ([
      "arn:aws:iam::111122223333:role/braintrust-byoc/BraintrustSupportRole-review",
      "arn:aws:iam::111122223333:role/braintrust-byoc/BraintrustObserverRole-review",
      "arn:aws:iam::111122223333:role/braintrust-byoc/BraintrustDiagnosticsRole-review",
      "arn:aws:iam::111122223333:role/bt-a-*"] | sort)' "$diagnostic_guardrail" >/dev/null
  jq -e '.Statement[] | select(.Sid == "ManageDataPlaneServices") |
    .Effect == "Allow" and (.Action | index("ecs:*") != null)' "$infrastructure" >/dev/null
  jq -e '.Statement[] | select(.Sid == "DenyManagementTranscriptWrites") |
    .Effect == "Deny" and
    (.Action | sort) == (["logs:CreateLogStream", "logs:PutLogEvents"] | sort) and
    .Resource == "arn:aws:logs:us-east-1:111122223333:log-group:/braintrust-byoc/review/diagnostics:*" and
    .Condition == {"ArnLike": {"aws:PrincipalArn":
      "arn:aws:iam::111122223333:role/braintrust-byoc/Braintrust*Role-review"}}' \
    "$diagnostic_guardrail" >/dev/null
  pattern="$(jq -r '.Statement[] | select(.Sid == "DenyManagementTranscriptWrites") |
    .Condition.ArnLike."aws:PrincipalArn"' "$diagnostic_guardrail")"
  for role_type in Deployment Support Observer Diagnostics; do
    if [[ "arn:aws:iam::111122223333:role/braintrust-byoc/Braintrust${role_type}Role-review" != $pattern ]]; then
      echo 'Transcript write denial must cover every management role.' >&2
      exit 1
    fi
  done
  # Instance/task roles must remain able to deliver transcripts.
  for writer in bt-a-one-BrainstoreRole bt-a-two-APIHandlerRole; do
    if [[ "arn:aws:iam::111122223333:role/${writer}" == $pattern ]]; then
      echo 'Transcript write denial must not match runtime delivery roles.' >&2
      exit 1
    fi
  done
  pattern="$(jq -er '.Statement[] | select(.Sid == "ReadManagedApplicationLogs") |
    .Resource[] | select(contains("/microvms/"))' "$diagnostics")"
  assert_scope "$pattern" \
    'arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/microvms/bt-loop-bt-a-one:*' \
    'arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/microvms/bt-loop-bt-a-two:*' \
    'arn:aws:logs:us-east-1:111122223333:log-group:/aws/lambda/microvms/bt-loop-bt-b-one:*'
  for file in "$temporary_dir/observer-policy.json" "$retained"; do
    jq -e '[.Statement[] | select(.Effect == "Deny") | .Action | if type == "array" then .[] else . end] |
      index("ssm:StartSession") != null and index("ecs:ExecuteCommand") != null and
      index("logs:GetLogEvents") != null and index("sts:AssumeRole") != null' "$file" >/dev/null
  done
  echo 'Diagnostics activation, transcript-writer separation, workload access denials, Loop logs, and EKS preparation checks passed (static checks only).'
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
