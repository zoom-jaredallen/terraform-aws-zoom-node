#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  check-ec2-capacity.sh --terraform-plan FILE [--capacity-manager-region REGION] [--minimum-score low|medium|high] [--output table|json]
  check-ec2-capacity.sh --region REGION --market-type on-demand|spot --capacity COUNT --availability-zone AZ [--availability-zone AZ...] --instance-type TYPE [--instance-type TYPE...] [--capacity-manager-region REGION] [--minimum-score low|medium|high] [--output table|json]
EOF
  exit 64
}

usage_error() { echo "Error: $*" >&2; usage; }
prerequisite_error() { echo "Capacity preflight unavailable: $*" >&2; exit 3; }

terraform_plan=""
region=""
capacity_manager_region=""
market_type=""
capacity=""
minimum_score="low"
output_mode="table"
availability_zones=()
instance_types=()
manual_argument_seen=false

while (($#)); do
  case "$1" in
    --terraform-plan) [[ $# -ge 2 ]] || usage; terraform_plan="$2"; shift 2 ;;
    --region) [[ $# -ge 2 ]] || usage; region="$2"; manual_argument_seen=true; shift 2 ;;
    --capacity-manager-region) [[ $# -ge 2 ]] || usage; capacity_manager_region="$2"; shift 2 ;;
    --market-type) [[ $# -ge 2 ]] || usage; market_type="$2"; manual_argument_seen=true; shift 2 ;;
    --capacity) [[ $# -ge 2 ]] || usage; capacity="$2"; manual_argument_seen=true; shift 2 ;;
    --availability-zone) [[ $# -ge 2 ]] || usage; availability_zones+=("$2"); manual_argument_seen=true; shift 2 ;;
    --instance-type) [[ $# -ge 2 ]] || usage; instance_types+=("$2"); manual_argument_seen=true; shift 2 ;;
    --minimum-score) [[ $# -ge 2 ]] || usage; minimum_score="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || usage; output_mode="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) usage_error "unknown argument $1" ;;
  esac
done

contains_value() {
  local wanted="$1"
  shift
  local candidate
  for candidate in "$@"; do
    [[ "$candidate" == "$wanted" ]] && return 0
  done
  return 1
}

contains_value "$minimum_score" low medium high || usage_error "minimum score must be low, medium, or high"
contains_value "$output_mode" table json || usage_error "output must be table or json"
if [[ -n "$terraform_plan" ]]; then
  [[ "$manual_argument_seen" == false ]] || usage_error "--terraform-plan and manual capacity arguments are mutually exclusive"
  [[ -f "$terraform_plan" ]] || usage_error "Terraform plan file does not exist: $terraform_plan"
else
  [[ "$manual_argument_seen" == true ]] || usage
  [[ -n "$region" && -n "$market_type" && -n "$capacity" ]] || usage_error "manual mode requires region, market type, and capacity"
  contains_value "$market_type" on-demand spot || usage_error "market type must be on-demand or spot"
  [[ "$capacity" =~ ^[1-9][0-9]*$ ]] || usage_error "capacity must be a positive integer"
  ((${#availability_zones[@]} > 0 && ${#instance_types[@]} > 0)) || usage_error "manual mode requires at least one Availability Zone and instance type"
fi
command -v jq >/dev/null 2>&1 || prerequisite_error "jq is required"
command -v aws >/dev/null 2>&1 || prerequisite_error "AWS CLI v2 is required"
aws_version="$(aws --version 2>&1 || true)"
[[ "$aws_version" == aws-cli/2.* ]] || prerequisite_error "AWS CLI v2 is required"
aws_cli_version="${aws_version#aws-cli/}"
aws_cli_version="${aws_cli_version%% *}"
IFS=. read -r aws_cli_major aws_cli_minor aws_cli_patch <<<"$aws_cli_version"
if ((aws_cli_major < 2 || (aws_cli_major == 2 && aws_cli_minor < 39) || (aws_cli_major == 2 && aws_cli_minor == 39 && aws_cli_patch < 1))); then
  prerequisite_error "AWS CLI 2.39.1 or newer is required for EC2 Capacity Manager supportability scores"
fi

umask 077
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
manifest_file="$temp_dir/capacity-manifest.json"

if [[ -n "$terraform_plan" ]]; then
  command -v terraform >/dev/null 2>&1 || prerequisite_error "Terraform is required for saved-plan mode"
  if ! terraform show -json "$terraform_plan" | jq -ce '
    .planned_values.outputs.capacity_preflight_requests as $output
    | if $output == null or $output.sensitive == true then error("missing or sensitive output") else $output.value end
    | if type != "array" or length == 0 then error("manifest must be a non-empty array") else . end
    | if all(.[];
        type == "object"
        and (keys | sort) == ["availability_zone", "instance_count", "instance_type", "market_type", "region"]
        and (.region | type == "string" and length > 0)
        and (.availability_zone | type == "string" and length > 0)
        and (.instance_type | type == "string" and length > 0)
        and (.market_type == "on-demand" or .market_type == "spot")
        and (.instance_count | type == "number" and . > 0 and floor == .)
      ) then . else error("invalid manifest entry") end
  ' >"$manifest_file"; then
    usage_error "invalid capacity_preflight_requests output in Terraform plan"
  fi
else
  zones_json="$(printf '%s\n' "${availability_zones[@]}" | jq -R . | jq -sc '.')"
  types_json="$(printf '%s\n' "${instance_types[@]}" | jq -R . | jq -sc '.')"
  jq -cn --arg region "$region" --arg market "$market_type" --argjson count "$capacity" --argjson zones "$zones_json" --argjson types "$types_json" \
    '[$zones[] as $zone | $types[] as $type | {region:$region, availability_zone:$zone, instance_type:$type, market_type:$market, instance_count:$count}]' >"$manifest_file"
fi

manifest_regions="$(jq -r 'map(.region) | unique | .[]' "$manifest_file")"
region_count="$(printf '%s\n' "$manifest_regions" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ -z "$capacity_manager_region" ]]; then
  [[ "$region_count" -eq 1 ]] || usage_error "--capacity-manager-region is required for multi-region Terraform plans"
  capacity_manager_region="$manifest_regions"
fi

aws sts get-caller-identity --output json >/dev/null 2>&1 || prerequisite_error "AWS authentication failed"
if ! attributes="$(aws ec2 get-capacity-manager-attributes --region "$capacity_manager_region" --output json 2>&1)"; then
  prerequisite_error "unable to read Capacity Manager attributes; check IAM permissions and the Capacity Manager Region"
fi
status="$(printf '%s' "$attributes" | jq -r '.CapacityManagerStatus // empty' 2>/dev/null || true)"
[[ "$status" == "enabled" ]] || prerequisite_error "Capacity Manager is not enabled in $capacity_manager_region"

zone_map='{}'
while IFS= read -r target_region; do
  [[ -n "$target_region" ]] || continue
  if ! zone_response="$(aws ec2 describe-availability-zones --region "$target_region" --output json 2>&1)"; then
    prerequisite_error "unable to describe Availability Zones in $target_region"
  fi
  region_map="$(printf '%s' "$zone_response" | jq -ce --arg region "$target_region" '.AvailabilityZones | map({key: ($region + "|" + .ZoneName), value: .ZoneId}) | from_entries' 2>/dev/null)" || prerequisite_error "AWS returned malformed Availability Zone data"
  zone_map="$(jq -cn --argjson current "$zone_map" --argjson addition "$region_map" '$current + $addition')"
done <<<"$manifest_regions"

missing_zones="$(jq -r --argjson zones "$zone_map" '[.[] | select($zones[.region + "|" + .availability_zone] == null) | .availability_zone] | unique | join(", ")' "$manifest_file")"
[[ -z "$missing_zones" ]] || usage_error "Availability Zones were not found for this account: $missing_zones"

results='[]'
while IFS= read -r request_group; do
  market="$(printf '%s' "$request_group" | jq -r '.[0].market_type')"
  count="$(printf '%s' "$request_group" | jq -r '.[0].instance_count')"
  request_instance_types=()
  while IFS= read -r value; do request_instance_types+=("$value"); done < <(printf '%s' "$request_group" | jq -r 'map(.instance_type) | unique | .[]')
  request_zone_ids=()
  while IFS= read -r value; do request_zone_ids+=("$value"); done < <(printf '%s' "$request_group" | jq -r --argjson zones "$zone_map" 'map($zones[.region + "|" + .availability_zone]) | unique | .[]')
  ((${#request_instance_types[@]} <= 50)) || usage_error "a Capacity Manager request supports at most 50 instance types"
  ((${#request_zone_ids[@]} <= 10)) || usage_error "a Capacity Manager request supports at most 10 Availability Zones"
  if ! response="$(aws ec2 get-capacity-manager-supportability-scores \
    --market-type "$market" --capacity-amount "$count" --capacity-unit instances \
    --capacity-availability-zone-ids "${request_zone_ids[@]}" --instance-types "${request_instance_types[@]}" \
    --region "$capacity_manager_region" --output json 2>&1)"; then
    prerequisite_error "supportability scoring failed; verify Unified Operations support and ec2:GetCapacityManagerSupportabilityScores permission"
  fi
  normalized="$(printf '%s' "$response" | jq -ce --arg market "$market" --argjson count "$count" --argjson zones "$zone_map" '
    if ((.AggregateScore == "low" or .AggregateScore == "medium" or .AggregateScore == "high")
      and (.CapacityManagerSupportabilityScores | type == "array")
      and all(.CapacityManagerSupportabilityScores[]; (.Score == "low" or .Score == "medium" or .Score == "high")))
    then {market_type:$market, instance_count:$count, aggregate_score:.AggregateScore,
      scores:[.CapacityManagerSupportabilityScores[] as $score | {instance_type:$score.InstanceType, availability_zone_id:$score.AvailabilityZoneId,
        availability_zone:(($zones | to_entries | map(select(.value == $score.AvailabilityZoneId)) | .[0].key // "unknown") | split("|") | .[-1]), score:$score.Score}]}
    else error("malformed response") end
  ' 2>/dev/null)" || prerequisite_error "AWS returned a malformed supportability score response"
  results="$(jq -cn --argjson current "$results" --argjson item "$normalized" '$current + [$item]')"
done < <(jq -c 'sort_by(.market_type, .instance_count) | group_by([.market_type, .instance_count])[]' "$manifest_file")

overall_score="$(printf '%s' "$results" | jq -r '[.[].aggregate_score, .[].scores[].score] | map(if . == "low" then 0 elif . == "medium" then 1 else 2 end) | min | if . == 0 then "low" elif . == 1 then "medium" else "high" end')"
minimum_met="$(jq -nr --arg actual "$overall_score" --arg required "$minimum_score" 'def rank: if . == "low" then 0 elif . == "medium" then 1 else 2 end; ($actual | rank) >= ($required | rank)')"

if [[ "$output_mode" == "json" ]]; then
  jq -n --arg capacity_manager_region "$capacity_manager_region" --arg overall_score "$overall_score" --arg minimum_score "$minimum_score" --argjson minimum_score_met "$minimum_met" --argjson requests "$results" \
    '{capacity_manager_region:$capacity_manager_region, overall_score:$overall_score, minimum_score:$minimum_score, minimum_score_met:$minimum_score_met, requests:$requests}'
else
  printf 'Capacity Manager region: %s\n' "$capacity_manager_region"
  printf 'Overall supportability: %s\n\n' "$overall_score"
  printf '%-12s %-8s %-10s %-22s %-20s %s\n' MARKET COUNT AGGREGATE INSTANCE_TYPE AVAILABILITY_ZONE SCORE
  printf '%s' "$results" | jq -r '.[] as $request | $request.scores[] | [$request.market_type, ($request.instance_count|tostring), $request.aggregate_score, .instance_type, .availability_zone, .score] | @tsv' |
    while IFS=$'\t' read -r row_market row_count aggregate instance_type availability_zone score; do
      printf '%-12s %-8s %-10s %-22s %-20s %s\n' "$row_market" "$row_count" "$aggregate" "$instance_type" "$availability_zone" "$score"
    done
fi

if [[ "$minimum_met" != "true" ]]; then
  echo "Supportability score $overall_score is below required minimum $minimum_score." >&2
  exit 2
fi
