#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  apply-with-diagnostics.sh --terraform-plan FILE [--capacity-manager-region REGION] [--minimum-score low|medium|high] [--allow-low-capacity] [--skip-capacity-check] [--auto-approve]
EOF
  exit 64
}

plan_file=""
capacity_manager_region=""
minimum_score="medium"
allow_low_capacity=false
skip_capacity_check=false
auto_approve=false

while (($#)); do
  case "$1" in
    --terraform-plan) [[ $# -ge 2 ]] || usage; plan_file="$2"; shift 2 ;;
    --capacity-manager-region) [[ $# -ge 2 ]] || usage; capacity_manager_region="$2"; shift 2 ;;
    --minimum-score) [[ $# -ge 2 ]] || usage; minimum_score="$2"; shift 2 ;;
    --allow-low-capacity) allow_low_capacity=true; shift ;;
    --skip-capacity-check) skip_capacity_check=true; shift ;;
    --auto-approve) auto_approve=true; shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

[[ -n "$plan_file" && -f "$plan_file" ]] || usage
case "$minimum_score" in low|medium|high) ;; *) usage ;; esac
if [[ "$skip_capacity_check" == true && "$allow_low_capacity" == true ]]; then
  echo "--skip-capacity-check and --allow-low-capacity cannot be used together." >&2
  exit 64
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
capacity_script="${ZOOM_NODE_CAPACITY_CHECK_SCRIPT:-$repo_root/scripts/check-ec2-capacity.sh}"

if [[ "$skip_capacity_check" == true ]]; then
  echo "Capacity preflight skipped explicitly."
else
  [[ -x "$capacity_script" ]] || { echo "Capacity preflight executable not found: $capacity_script" >&2; exit 3; }
  capacity_args=(--terraform-plan "$plan_file" --minimum-score "$minimum_score")
  if [[ -n "$capacity_manager_region" ]]; then
    capacity_args+=(--capacity-manager-region "$capacity_manager_region")
  fi

  set +e
  "$capacity_script" "${capacity_args[@]}"
  capacity_status=$?
  set -e

  case "$capacity_status" in
    0) ;;
    2)
      if [[ "$allow_low_capacity" == true ]]; then
        echo "Proceeding despite a below-threshold capacity score because --allow-low-capacity was supplied."
      else
        cat >&2 <<'EOF'
Terraform apply was not started because EC2 supportability is below the required minimum.
Select another Availability Zone, Region, or compatible instance type; retry later; or reserve capacity.
Use --allow-low-capacity to make an informed launch attempt with the current saved plan.
EOF
        exit 2
      fi
      ;;
    3)
      cat >&2 <<'EOF'
Capacity preflight could not run, so Terraform apply was not started.
Resolve the reported Capacity Manager prerequisite or use --skip-capacity-check to proceed explicitly.
EOF
      exit 3
      ;;
    *)
      echo "Capacity preflight failed with exit status $capacity_status; Terraform apply was not started." >&2
      exit "$capacity_status"
      ;;
  esac
fi

command -v terraform >/dev/null 2>&1 || { echo "terraform was not found in PATH." >&2; exit 3; }

umask 077
diagnostic_log="$(mktemp "${TMPDIR:-/tmp}/zoom-node-apply.XXXXXX")"
trap 'rm -f "$diagnostic_log"' EXIT

apply_args=(apply -no-color)
if [[ "$auto_approve" == true ]]; then
  apply_args+=(-auto-approve)
fi
apply_args+=("$plan_file")

set +e
terraform "${apply_args[@]}" 2>&1 | tee "$diagnostic_log"
terraform_status=${PIPESTATUS[0]}
set -e

if [[ "$terraform_status" -eq 0 ]]; then
  exit 0
fi

extract_first() {
  sed -nE \
    -e "$1" \
    -e 't found' \
    -e 'b' \
    -e ':found' \
    -e 'q' \
    "$diagnostic_log"
}

print_common_footer() {
  cat <<'EOF'

No automatic placement changes were made. Generate and review a new Terraform plan before retrying.
Terraform applies are not transactional; supporting resources may already exist even though the EC2 instance was not created.
EOF
}

if grep -q 'InsufficientInstanceCapacity' "$diagnostic_log"; then
  instance_type="$(extract_first 's/.*sufficient ([[:alnum:]._-]+) capacity.*/\1/p')"
  availability_zone="$(extract_first 's/.*Availability Zone you requested \(([^)]+)\).*/\1/p')"
  node_resource="$(extract_first 's/^[[:space:]]*with (.*),[[:space:]]*$/\1/p')"
  alternatives="$(extract_first 's/.* or choosing ([^.]+)\..*/\1/p')"

  cat <<'EOF'

Zoom Node deployment stopped
AWS currently has insufficient EC2 capacity for this launch.
EOF
  [[ -n "$instance_type" ]] && printf '  Instance type: %s\n' "$instance_type"
  [[ -n "$availability_zone" ]] && printf '  Availability Zone: %s\n' "$availability_zone"
  [[ -n "$node_resource" ]] && printf '  Node resource: %s\n' "$node_resource"
  [[ -n "$alternatives" ]] && printf '  AWS suggested: %s\n' "$alternatives"
  cat <<'EOF'

Choose another Availability Zone or Region, use a compatible instance type, retry later, or reserve capacity.
EOF
  print_common_footer
elif grep -q 'InsufficientFreeAddressesInSubnet' "$diagnostic_log"; then
  printf '\nZoom Node deployment stopped\nThe selected subnet does not have enough free private IP addresses.\n'
  print_common_footer
elif grep -q 'InstanceLimitExceeded' "$diagnostic_log"; then
  printf '\nZoom Node deployment stopped\nThe account instance limit prevents this launch. Request a quota increase or reduce the deployment size.\n'
  print_common_footer
elif grep -q 'VcpuLimitExceeded' "$diagnostic_log"; then
  printf '\nZoom Node deployment stopped\nThe account vCPU quota prevents this launch. Request the applicable On-Demand or Spot vCPU quota increase.\n'
  print_common_footer
elif grep -q 'MaxSpotInstanceCountExceeded' "$diagnostic_log"; then
  printf '\nZoom Node deployment stopped\nThe account Spot Instance limit prevents this launch. Request a quota increase or reduce the Spot deployment size.\n'
  print_common_footer
elif grep -qE 'api error Unsupported:|UnsupportedOperation|UnsupportedInstanceAttribute' "$diagnostic_log"; then
  printf '\nZoom Node deployment stopped\nAWS rejected the selected instance configuration. Verify the instance type, AMI architecture, subnet Availability Zone, and requested EC2 features.\n'
  print_common_footer
fi

exit "$terraform_status"
