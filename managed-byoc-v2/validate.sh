#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "Validation failed at %s:%s; review the preceding static check.\n" "${BASH_SOURCE[0]}" "$LINENO" >&2' ERR

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

# Verify source policy provenance without comparing rendered customer values
# against placeholder-template digests.
if [[ "$package_dir" == "$source_dir" ]]; then
  command -v shasum >/dev/null
  jq -e '.profile == "customer" and .audience == "customer" and
    .status == "design-preview" and .deployment_ready == false and
    .default_deprovision_mode == "retain-data" and
    .allowed_deprovision_modes == ["retain-data"]' "$source_dir/contract.json" >/dev/null
  while IFS=$'\t' read -r relative expected; do
    actual="$(shasum -a 256 "$source_dir/$relative" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || {
      echo "Source policy digest mismatch: $relative" >&2
      exit 1
    }
  done < <(jq -r '.policy_sha256 | to_entries[] | [.key, .value] | @tsv' "$source_dir/contract.json")
fi

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
    # ARN prefix plus suffix consume 36 characters, leaving 220 at the limit.
    sample_principal="arn:aws:iam::444455556666:role/$(printf '%220s' '' | tr ' ' p)/role"
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
  local eks_file="$temporary_dir/${fixture}deployment-eks-policy.json"
  role="$(jq -er '.Statement[] | select(.Sid == "ActivatePredefinedDiagnostics") | .Resource' "$activation_file")"
  role_pattern='^arn:aws:iam::([0-9]{12}):role/braintrust-byoc/BraintrustDiagnosticsRole-([a-z0-9][a-z0-9-]{0,15})$'
  if [[ ! "$role" =~ $role_pattern ]]; then
    echo 'Diagnostics role must use the protected IAM path and a bootstrap identifier of at most 16 characters.' >&2
    exit 1
  fi
  account="${BASH_REMATCH[1]}"
  bootstrap="${BASH_REMATCH[2]}"
  policy="$(jq -cer '.Statement[] | select(.Sid == "ActivatePredefinedDiagnostics") | .Condition.ArnEquals."iam:PolicyARN"' "$activation_file")"
  runtime_boundary="arn:aws:iam::${account}:policy/braintrust-byoc/BraintrustRuntimeBoundary-${bootstrap}"
  jq -e --arg account "$account" --arg bootstrap "$bootstrap" '
    .Statement[] | select(.Sid == "ActivatePredefinedDiagnostics") |
    .Condition.ArnEquals."iam:PolicyARN" | sort ==
      (["BraintrustInspectionPolicy", "BraintrustDiagnosticsPolicy"] |
       map("arn:aws:iam::" + $account + ":policy/braintrust-byoc/" + . + "-" + $bootstrap) | sort)' \
    "$activation_file" >/dev/null
  jq -e --arg boundary "$runtime_boundary" '[.Statement[] |
    select(.Sid == "CreateBoundedRoles" or .Sid == "SetRuntimeBoundary") |
    .Condition.ArnEquals."iam:PermissionsBoundary" == $boundary] == [true,true]' "$infrastructure_file" >/dev/null
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
  [[ "$state_resource" == "arn:aws:s3:::${state_bucket}/braintrust-byoc/${bootstrap}/*" ]] || {
    echo 'State resource does not match its bootstrap root.' >&2
    exit 1
  }
  [[ "$operation_resource" == "arn:aws:s3:::${operation_bucket}/braintrust-byoc/operations/${bootstrap}/*" ]] || {
    echo 'Operation log resource does not match its bootstrap root.' >&2
    exit 1
  }
  for bucket in "$state_bucket" "$operation_bucket"; do
    if [[ "$bucket" == "$prefix"* || ${#bucket} -gt 63 || ${#bucket} -lt 3 ]]; then
      echo 'Bootstrap buckets must be outside the runtime prefix and use valid S3 name lengths.' >&2
      exit 1
    fi
  done
  [[ "$state_bucket" != "$operation_bucket" ]] || {
    echo 'State and operation log buckets must differ.' >&2
    exit 1
  }
  license="$(jq -er '.Statement[] | select(.Sid == "ReadLicenseSecret") | .Resource' "$data_file")"
  [[ ${#license} -le 128 && "$license" != *'*'* && "$license" != *'?'* ]] || {
    echo 'License secret ARN must be exact and at most 128 characters.' >&2
    exit 1
  }
  for trust in deployment-role-trust-policy.json human-role-trust-policy.json; do
    principal="$(jq -er '.Statement[0].Principal.AWS' "$temporary_dir/${fixture}${trust}")"
    role_pattern='^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9_+=,.@/-]+$'
    [[ "$principal" =~ $role_pattern && ${#principal} -le 256 ]] || {
      echo 'Trusted principal must be an exact role ARN of at most 256 characters.' >&2
      exit 1
    }
  done
  external_id="$(jq -er '.Statement[0].Condition.StringEquals."sts:ExternalId"' "$temporary_dir/${fixture}deployment-role-trust-policy.json")"
  [[ ${#external_id} -ge 2 && ${#external_id} -le 128 ]] || {
    echo 'External ID must be between 2 and 128 characters.' >&2
    exit 1
  }
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
echo 'Bootstrap naming, protected IAM paths, input lengths, and activation-policy checks passed.'


assert_policy() {
  local file="$1" expression="$2"
  if ! jq -e "$expression" "$temporary_dir/$file" >/dev/null; then
    echo "Static invariant failed in $file" >&2
    exit 1
  fi
}
for file in "${policy_files[@]}"; do
  assert_policy "$(basename "$file")" \
    '.Statement | all(has("Action") and (has("NotAction") | not) and
      (.Effect == "Allow"))'
done
for file in "${scp_files[@]}"; do
  assert_policy "$(basename "$file")" '.Statement | all(.Effect == "Deny" and (has("Condition") | not))'
done
if [[ -e "$policy_dir/deployment-guardrail-policy.json" || -e "$policy_dir/observer-policy.json" ]]; then
  echo 'The replaced subtractive policies must not remain in the attachment set.' >&2
  exit 1
fi
echo 'Positive identity policies and runtime ceiling; one account-wide SCP.'

if [[ "$package_dir" == "$source_dir" ]]; then
  [[ ${#scp_files[@]} -eq 1 ]] || {
    echo 'Exactly one account SCP is required.' >&2
    exit 1
  }
  assert_policy customer-service-control-policy.json '
    (.Statement | map(.Sid) | sort) ==
      (["ProtectOrganizationMembership", "ProtectAccountPublicAccessBlock",
        "ProtectSecurityServices", "ProtectRetainedData", "DenySnapshotAndImageSharing"] | sort)'
  assert_policy customer-service-control-policy.json '
    [.Statement[] | select(.Sid == "ProtectRetainedData") |
      (.Action | sort) == (["kms:ScheduleKeyDeletion", "rds:DeleteDBSnapshot", "s3:DeleteBucket"] | sort) and
      (.Resource | sort) == (["arn:aws:kms:*:*:key/*",
        "arn:aws:rds:*:*:snapshot:*-main-final-snapshot-*", "arn:aws:s3:::*-brainstore-*"] | sort)] == [true]'
  assert_policy deployment-infrastructure-policy.json '
    (.Statement[] | select(.Sid == "ManageDataPlaneServices") | .Action) as $actions |
    ($actions | index("ecs:Update*") != null) and
    (["ecs:*", "ecs:ExecuteCommand", "dynamodb:*", "eks:*", "ec2-instance-connect:*",
      "cloudwatch:*", "lambda:*", "logs:*"] |
      all(. as $action | $actions | index($action) == null))'
  assert_policy inspection-policy.json '
    [.Statement[].Action | if type == "array" then .[] else . end] |
    all(. != "ec2:Describe*" and . != "ecs:Describe*" and . != "autoscaling:Describe*" and
        . != "ec2:DescribeInstanceAttribute" and . != "ec2:DescribeLaunchTemplateVersions" and
        . != "ecs:DescribeTaskDefinition" and . != "autoscaling:DescribeLaunchConfigurations")'
  assert_policy runtime-permissions-boundary.json '
    ([.Statement[] | select(.Sid == "AllowInternalRuntimeRoleAssumptions") |
      .Action == "sts:AssumeRole" and (.Resource | length) == 2 and
      .Condition.ArnLike."aws:PrincipalArn" == "arn:aws:iam::111122223333:role/bt-a-*-APIHandlerRole"] == [true]) and
    ([.Statement[] | select(.Sid == "AllowWorkloadStorageOutsideBootstrap") |
      (.NotResource | length) == 6] == [true])'
  assert_policy deployment-workload-policy.json '
    [.Statement[] | select(.Sid == "ManageLogGroupConfiguration") |
      .NotResource == ["arn:aws:logs:us-east-1:111122223333:log-group:/braintrust-byoc/review/diagnostics",
        "arn:aws:logs:us-east-1:111122223333:log-group:/braintrust-byoc/review/diagnostics:*"]] == [true]'
  assert_policy diagnostics-policy.json '
    ([.Statement[] | select(.Sid == "StartBrainstoreShell") |
      .Condition.BoolIfExists."ssm:SessionDocumentAccessCheck" == "true" and
      .Condition.StringLike."ssm:resourceTag/BraintrustDeploymentName" == "bt-a-*" and
      (.Condition.StringEquals."ssm:resourceTag/BrainstoreRole" | length) == 4] == [true]) and
    ([.Statement[] | select(.Sid == "UseLoggedShellDocument") |
      .Resource == "arn:aws:ssm:us-east-1:111122223333:document/BraintrustDiagnosticsShell-review"] == [true])'
  assert_policy deployment-diagnostics-policy.json '
    ([.Statement[] | select(.Sid == "CloseDiagnosticSessions") |
      .Condition.StringLike."ssm:resourceTag/aws:ssmmessages:session-id" == "AROADIAGNOSTICSEXAMPLE:*"] == [true]) and
    ([.Statement[] | select(.Sid == "CloseManagedEcsSessions") |
      .Condition.StringLike."ssm:resourceTag/aws:ssmmessages:target-id" == "ecs:bt-a-*_*_*"] == [true]) and
    ([.Statement[] | select(.Sid == "AttributeEcsDiagnosticSessions") |
      .Action == "cloudtrail:LookupEvents" and
      .Condition.StringEquals."aws:RequestedRegion" == "us-east-1"] == [true])'
  assert_policy deployment-eks-policy.json '
    ([.Statement[] | select(.Sid | startswith("Create") and endswith("ClusterEntry")) |
      .Condition.StringEquals."eks:accessEntryType" == "STANDARD" and
      .Condition.Null."eks:kubernetesGroups" == "false" and
      .Condition.Null."eks:username" == "true"] == [true,true]) and
    ([.Statement[].Action | if type == "array" then .[] else . end] |
      all(. != "eks:*" and . != "eks:UpdateAccessEntry" and . != "eks:AssociateAccessPolicy"))'
  echo 'Account guardrails, positive role grants, delegation, and diagnostic boundaries passed (static checks only).'
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
