#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/check-ec2-capacity.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
export FAKE_AWS_LOG="$test_root/aws.log"
export REAL_JQ="$(command -v jq)"

cat >"$fake_bin/jq" <<'EOF'
#!/usr/bin/env bash
exec "$REAL_JQ" "$@"
EOF

cat >"$fake_bin/terraform" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "show" && "${2:-}" == "-json" ]]; then
  printf '%s\n' "$FAKE_PLAN_JSON"
  exit 0
fi
exit 64
EOF

cat >"$fake_bin/aws" <<'EOF'
#!/usr/bin/env bash
printf '%q ' "$@" >>"$FAKE_AWS_LOG"
printf '\n' >>"$FAKE_AWS_LOG"

if [[ "${1:-}" == "--version" ]]; then
  printf 'aws-cli/%s Python/3.13 Darwin/24 exe/x86_64\n' "${FAKE_AWS_VERSION:-2.39.3}"
  exit 0
fi
if [[ "${1:-}" == "sts" && "${2:-}" == "get-caller-identity" ]]; then
  echo '{"Account":"123456789012","Arn":"arn:aws:iam::123456789012:user/test","UserId":"test"}'
  exit 0
fi
if [[ "${1:-}" == "ec2" && "${2:-}" == "get-capacity-manager-attributes" ]]; then
  if [[ "${FAKE_ATTRIBUTES_ERROR:-}" == "disabled" ]]; then
    echo "An error occurred (CapacityManager.Disabled) when calling the GetCapacityManagerAttributes operation: Capacity Manager isn't enabled for this account." >&2
    exit 254
  fi
  if [[ "${FAKE_ATTRIBUTES_ERROR:-}" == "true" ]]; then
    echo 'AccessDenied: not authorized' >&2
    exit 255
  fi
  printf '{"CapacityManagerStatus":"%s","IngestionStatus":"ingestion-complete"}\n' "${FAKE_CAPACITY_MANAGER_STATUS:-enabled}"
  exit 0
fi
if [[ "${1:-}" == "ec2" && "${2:-}" == "describe-availability-zones" ]]; then
  region=''
  shift 2
  while (($#)); do
    if [[ "$1" == "--region" ]]; then region="$2"; shift 2; else shift; fi
  done
  case "$region" in
    us-west-2) echo '{"AvailabilityZones":[{"ZoneName":"us-west-2a","ZoneId":"usw2-az1"},{"ZoneName":"us-west-2b","ZoneId":"usw2-az2"}]}' ;;
    ap-southeast-2) echo '{"AvailabilityZones":[{"ZoneName":"ap-southeast-2a","ZoneId":"apse2-az1"}]}' ;;
    *) exit 1 ;;
  esac
  exit 0
fi
if [[ "${1:-}" == "ec2" && "${2:-}" == "get-capacity-manager-supportability-scores" ]]; then
  if [[ "${FAKE_SCORE_ERROR:-}" == "true" ]]; then
    echo 'SubscriptionRequiredException: Unified Operations required' >&2
    exit 255
  fi
  if [[ "${FAKE_MALFORMED_SCORE:-}" == "true" ]]; then
    echo '{"unexpected":true}'
    exit 0
  fi
  score="${FAKE_SCORE:-high}"
  echo "{\"AggregateScore\":\"$score\",\"CapacityManagerSupportabilityScores\":[{\"InstanceType\":\"g5.12xlarge\",\"AvailabilityZoneId\":\"usw2-az2\",\"Score\":\"$score\"}]}"
  exit 0
fi
exit 64
EOF

chmod +x "$fake_bin/aws" "$fake_bin/jq" "$fake_bin/terraform"
export PATH="$fake_bin:$PATH"
mkdir -p "$test_root/tmp"
export TMPDIR="$test_root/tmp"

pass_count=0
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "expected output to contain: $2"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "output leaked: $2"; }
assert_status() { [[ "$1" -eq "$2" ]] || fail "expected status $2, got $1"; }
run_case() {
  local expected_status="$1"
  shift
  set +e
  CASE_OUTPUT="$($script "$@" 2>&1)"
  CASE_STATUS=$?
  set -e
  assert_status "$CASE_STATUS" "$expected_status"
  pass_count=$((pass_count + 1))
}

export FAKE_AWS_VERSION=2.35.8
run_case 64
run_case 3 --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge
assert_contains "$CASE_OUTPUT" '2.39.1 or newer'
unset FAKE_AWS_VERSION

plan_file="$test_root/tfplan"
: >"$plan_file"
secret='ZoomNodeSecret-DoNotPrint'
export FAKE_PLAN_JSON="$(jq -cn --arg secret "$secret" '{planned_values:{root_module:{resources:[{values:{user_data:$secret}}]},outputs:{capacity_preflight_requests:{sensitive:false,value:[{region:"us-west-2",availability_zone:"us-west-2b",instance_type:"g5.12xlarge",market_type:"on-demand",instance_count:2},{region:"us-west-2",availability_zone:"us-west-2a",instance_type:"c6i.2xlarge",market_type:"spot",instance_count:1}]}}}}')"
: >"$FAKE_AWS_LOG"
run_case 0 --terraform-plan "$plan_file" --capacity-manager-region us-west-2
assert_contains "$CASE_OUTPUT" 'high'
assert_not_contains "$CASE_OUTPUT" "$secret"
[[ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]] || fail "temporary plan extraction artifacts were retained"
[[ "$(grep -c 'get-capacity-manager-supportability-scores' "$FAKE_AWS_LOG")" -eq 2 ]] || fail "plan requests were not grouped by market and count"
assert_contains "$(cat "$FAKE_AWS_LOG")" '--capacity-amount 2'
assert_contains "$(cat "$FAKE_AWS_LOG")" '--market-type spot'
assert_contains "$(cat "$FAKE_AWS_LOG")" 'get-capacity-manager-attributes --region us-west-2'

export FAKE_PLAN_JSON='{"planned_values":{"outputs":{"capacity_preflight_requests":{"sensitive":false,"value":[{"region":"us-west-2","availability_zone":"us-west-2a","instance_type":"c8i-flex.2xlarge","market_type":"on-demand","instance_count":1},{"region":"us-west-2","availability_zone":"us-west-2b","instance_type":"g6.12xlarge","market_type":"on-demand","instance_count":1}]}}}}'
: >"$FAKE_AWS_LOG"
run_case 0 --terraform-plan "$plan_file" --capacity-manager-region us-west-2
[[ "$(grep -c 'get-capacity-manager-supportability-scores' "$FAKE_AWS_LOG")" -eq 2 ]] || fail "plan requests in different Availability Zones were combined"
zone_a_request="$(grep 'get-capacity-manager-supportability-scores.*usw2-az1' "$FAKE_AWS_LOG")"
zone_b_request="$(grep 'get-capacity-manager-supportability-scores.*usw2-az2' "$FAKE_AWS_LOG")"
assert_contains "$zone_a_request" 'c8i-flex.2xlarge'
assert_not_contains "$zone_a_request" 'g6.12xlarge'
assert_contains "$zone_b_request" 'g6.12xlarge'
assert_not_contains "$zone_b_request" 'c8i-flex.2xlarge'

run_case 64 --terraform-plan "$plan_file" --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge
assert_contains "$CASE_OUTPUT" 'mutually exclusive'

export FAKE_PLAN_JSON='{"planned_values":{"outputs":{"capacity_preflight_requests":{"value":[{"region":"us-west-2","availability_zone":"us-west-2a","instance_type":"g5.12xlarge","market_type":"on-demand","instance_count":1,"password":"secret"}]}}}}'
run_case 64 --terraform-plan "$plan_file"
assert_contains "$CASE_OUTPUT" 'invalid capacity_preflight_requests'

export FAKE_PLAN_JSON='{"planned_values":{"outputs":{}}}'
run_case 64 --terraform-plan "$plan_file"
assert_contains "$CASE_OUTPUT" 'invalid capacity_preflight_requests'

export FAKE_PLAN_JSON='{"planned_values":{"outputs":{"capacity_preflight_requests":{"sensitive":true,"value":[]}}}}'
run_case 64 --terraform-plan "$plan_file"
assert_contains "$CASE_OUTPUT" 'invalid capacity_preflight_requests'

export FAKE_PLAN_JSON='{"planned_values":{"outputs":{"capacity_preflight_requests":{"sensitive":false,"value":[{"region":"us-west-2","availability_zone":"us-west-2a","instance_type":"g5.12xlarge","market_type":"on-demand","instance_count":1},{"region":"ap-southeast-2","availability_zone":"ap-southeast-2a","instance_type":"g5.12xlarge","market_type":"on-demand","instance_count":1}]}}}}'
run_case 64 --terraform-plan "$plan_file"
assert_contains "$CASE_OUTPUT" 'required for multi-region'
run_case 0 --terraform-plan "$plan_file" --capacity-manager-region us-west-2

export FAKE_SCORE=low
run_case 2 --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge --minimum-score medium
assert_contains "$CASE_OUTPUT" 'below required minimum'
unset FAKE_SCORE

export FAKE_CAPACITY_MANAGER_STATUS=disabled
run_case 3 --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge
assert_contains "$CASE_OUTPUT" 'not enabled'
unset FAKE_CAPACITY_MANAGER_STATUS

export FAKE_ATTRIBUTES_ERROR=disabled
run_case 3 --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge
assert_contains "$CASE_OUTPUT" 'Capacity Manager is not enabled in us-west-2'
unset FAKE_ATTRIBUTES_ERROR

export FAKE_ATTRIBUTES_ERROR=true
run_case 3 --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge
assert_contains "$CASE_OUTPUT" 'check IAM permissions'
unset FAKE_ATTRIBUTES_ERROR

export FAKE_SCORE_ERROR=true
run_case 3 --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge
assert_contains "$CASE_OUTPUT" 'Unified Operations'
unset FAKE_SCORE_ERROR

export FAKE_MALFORMED_SCORE=true
run_case 3 --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge
assert_contains "$CASE_OUTPUT" 'malformed supportability score response'
unset FAKE_MALFORMED_SCORE

run_case 0 --region us-west-2 --market-type on-demand --capacity 1 --availability-zone us-west-2a --instance-type g5.12xlarge --output json
echo "$CASE_OUTPUT" | jq -e '.minimum_score_met == true and .requests[0].aggregate_score == "high"' >/dev/null || fail "JSON output contract is invalid"

echo "Capacity preflight tests passed: $pass_count"
