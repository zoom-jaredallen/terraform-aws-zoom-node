#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/apply-with-diagnostics.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
mkdir -p "$fake_bin" "$test_root/tmp"
export TMPDIR="$test_root/tmp"
export FAKE_TERRAFORM_LOG="$test_root/terraform.log"
export FAKE_CAPACITY_LOG="$test_root/capacity.log"

cat >"$fake_bin/terraform" <<'EOF'
#!/usr/bin/env bash
printf '%q ' "$@" >>"$FAKE_TERRAFORM_LOG"
printf '\n' >>"$FAKE_TERRAFORM_LOG"
printf '%s\n' "${FAKE_TERRAFORM_OUTPUT:-Apply complete! Resources: 1 added, 0 changed, 0 destroyed.}"
exit "${FAKE_TERRAFORM_STATUS:-0}"
EOF

cat >"$fake_bin/check-ec2-capacity.sh" <<'EOF'
#!/usr/bin/env bash
printf '%q ' "$@" >>"$FAKE_CAPACITY_LOG"
printf '\n' >>"$FAKE_CAPACITY_LOG"
printf '%s\n' "${FAKE_CAPACITY_OUTPUT:-Overall supportability: high}"
exit "${FAKE_CAPACITY_STATUS:-0}"
EOF

chmod +x "$fake_bin/terraform" "$fake_bin/check-ec2-capacity.sh"
export PATH="$fake_bin:$PATH"
export ZOOM_NODE_CAPACITY_CHECK_SCRIPT="$fake_bin/check-ec2-capacity.sh"

plan_file="$test_root/tfplan"
: >"$plan_file"

pass_count=0
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "expected output to contain: $2"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "expected output not to contain: $2"; }
assert_status() { [[ "$1" -eq "$2" ]] || fail "expected status $2, got $1"; }
assert_empty_file() { [[ ! -s "$1" ]] || fail "expected $1 to be empty"; }
run_case() {
  local expected_status="$1"
  shift
  : >"$FAKE_TERRAFORM_LOG"
  : >"$FAKE_CAPACITY_LOG"
  set +e
  CASE_OUTPUT="$($script "$@" 2>&1)"
  CASE_STATUS=$?
  set -e
  assert_status "$CASE_STATUS" "$expected_status"
  pass_count=$((pass_count + 1))
}

run_case 64
assert_contains "$CASE_OUTPUT" 'Usage:'

export FAKE_CAPACITY_STATUS=0
export FAKE_TERRAFORM_STATUS=0
run_case 0 --terraform-plan "$plan_file" --capacity-manager-region us-west-2
assert_contains "$CASE_OUTPUT" 'Apply complete!'
assert_contains "$(cat "$FAKE_CAPACITY_LOG")" '--minimum-score medium'
assert_contains "$(cat "$FAKE_CAPACITY_LOG")" '--capacity-manager-region us-west-2'
assert_contains "$(cat "$FAKE_TERRAFORM_LOG")" "apply -no-color $plan_file"

export FAKE_CAPACITY_STATUS=2
export FAKE_CAPACITY_OUTPUT='Supportability score low is below required minimum medium.'
run_case 2 --terraform-plan "$plan_file"
assert_contains "$CASE_OUTPUT" 'Terraform apply was not started'
assert_contains "$CASE_OUTPUT" '--allow-low-capacity'
assert_empty_file "$FAKE_TERRAFORM_LOG"

run_case 0 --terraform-plan "$plan_file" --allow-low-capacity
assert_contains "$CASE_OUTPUT" 'Proceeding despite a below-threshold capacity score'
assert_contains "$(cat "$FAKE_TERRAFORM_LOG")" 'apply'

export FAKE_CAPACITY_STATUS=3
export FAKE_CAPACITY_OUTPUT='Capacity preflight unavailable.'
run_case 3 --terraform-plan "$plan_file"
assert_contains "$CASE_OUTPUT" 'Capacity preflight could not run'
assert_contains "$CASE_OUTPUT" '--skip-capacity-check'
assert_empty_file "$FAKE_TERRAFORM_LOG"

export FAKE_CAPACITY_STATUS=0
export FAKE_CAPACITY_OUTPUT='Overall supportability: high'
run_case 0 --terraform-plan "$plan_file" --skip-capacity-check
assert_empty_file "$FAKE_CAPACITY_LOG"
assert_contains "$CASE_OUTPUT" 'Capacity preflight skipped explicitly'

run_case 64 --terraform-plan "$plan_file" --skip-capacity-check --allow-low-capacity
assert_contains "$CASE_OUTPUT" 'cannot be used together'

export FAKE_TERRAFORM_STATUS=1
export FAKE_TERRAFORM_OUTPUT='Error: creating EC2 Instance: api error InsufficientInstanceCapacity: We currently do not have sufficient g6.12xlarge capacity in the Availability Zone you requested (us-east-1b). You can currently get g6.12xlarge capacity by not specifying an Availability Zone in your request or choosing us-east-1a, us-east-1c, us-east-1d, us-east-1f.

  with module.zoom_node.module.node.aws_instance.zoom_node["ai_services-01"],
  on ../../modules/node/main.tf line 66, in resource "aws_instance" "zoom_node":'
run_case 1 --terraform-plan "$plan_file" --skip-capacity-check
assert_contains "$CASE_OUTPUT" 'InsufficientInstanceCapacity'
assert_contains "$CASE_OUTPUT" 'AWS currently has insufficient EC2 capacity'
assert_contains "$CASE_OUTPUT" 'Instance type: g6.12xlarge'
assert_contains "$CASE_OUTPUT" 'Availability Zone: us-east-1b'
assert_contains "$CASE_OUTPUT" 'Node resource: module.zoom_node.module.node.aws_instance.zoom_node["ai_services-01"]'
assert_contains "$CASE_OUTPUT" 'AWS suggested: us-east-1a, us-east-1c, us-east-1d, us-east-1f'
assert_contains "$CASE_OUTPUT" 'No automatic placement changes were made'
assert_contains "$CASE_OUTPUT" 'supporting resources may already exist'

repeated_resource_lines="$(awk 'BEGIN { for (i = 0; i < 5000; i++) print "  with module.zoom_node.module.node.aws_instance.zoom_node[\"ai_services-01\"]," }')"
export FAKE_TERRAFORM_STATUS=7
export FAKE_TERRAFORM_OUTPUT="Error: api error InsufficientInstanceCapacity: We currently do not have sufficient g6.12xlarge capacity in the Availability Zone you requested (us-east-1b).
$repeated_resource_lines"
run_case 7 --terraform-plan "$plan_file" --skip-capacity-check
assert_contains "$CASE_OUTPUT" 'AWS currently has insufficient EC2 capacity'
assert_contains "$CASE_OUTPUT" 'Node resource: module.zoom_node.module.node.aws_instance.zoom_node["ai_services-01"]'

export FAKE_TERRAFORM_STATUS=1
known_errors=(
  'InsufficientFreeAddressesInSubnet|The selected subnet does not have enough free private IP addresses'
  'InstanceLimitExceeded|The account instance limit prevents this launch'
  'VcpuLimitExceeded|The account vCPU quota prevents this launch'
  'MaxSpotInstanceCountExceeded|The account Spot Instance limit prevents this launch'
  'Unsupported|AWS rejected the selected instance configuration'
)
for known_error in "${known_errors[@]}"; do
  error_code="${known_error%%|*}"
  expected_message="${known_error#*|}"
  export FAKE_TERRAFORM_OUTPUT="Error: api error $error_code: simulated failure"
  run_case 1 --terraform-plan "$plan_file" --skip-capacity-check
  assert_contains "$CASE_OUTPUT" "$expected_message"
done

export FAKE_TERRAFORM_STATUS=7
export FAKE_TERRAFORM_OUTPUT='Error: an unclassified Terraform failure'
run_case 7 --terraform-plan "$plan_file" --skip-capacity-check --auto-approve
assert_contains "$CASE_OUTPUT" 'unclassified Terraform failure'
assert_not_contains "$CASE_OUTPUT" 'Zoom Node deployment stopped'
assert_contains "$(cat "$FAKE_TERRAFORM_LOG")" 'apply -no-color -auto-approve'

[[ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]] || fail 'temporary diagnostic files were retained'

echo "Guarded apply tests passed: $pass_count"
