#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

required_runs=(
  plan_meetings_hybrid_workload
  plan_hybrid_recording_workload
  plan_meeting_survivability_workload
  plan_web_application_gateway_workload
  plan_ai_services_workload
  plan_phone_local_survivability_workload
  plan_create_new_single_az
  plan_create_new_dual_az
  plan_use_existing_network
  plan_private_nodes_with_nat_gateway
  plan_global_spot_workloads
  reject_overlapping_static_ip_ranges
  reject_static_ip_subnet_exhaustion
  plan_prod_image_catalog
  plan_dev_image_catalog
  plan_catalog_nic_mappings
  plan_nic_mapping_overrides
  plan_global_nic_override
  plan_per_node_overrides
  plan_hybrid_recording_create_new_bucket
  plan_hybrid_recording_use_existing_bucket
  plan_advanced_s3_bucket_modes
)

missing_runs=()

for run_name in "${required_runs[@]}"; do
  if ! rg --quiet --glob '*.tftest.hcl' "^[[:space:]]*run \"${run_name}\"" tests; then
    missing_runs+=("$run_name")
  fi
done

if ((${#missing_runs[@]} > 0)); then
  printf 'Missing required Terraform contract runs:\n' >&2
  printf '  - %s\n' "${missing_runs[@]}" >&2
  exit 1
fi

printf 'All %d required Terraform contract runs are present.\n' "${#required_runs[@]}"
