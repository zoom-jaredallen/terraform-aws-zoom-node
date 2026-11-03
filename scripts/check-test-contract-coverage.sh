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
  plan_control_plane_virtual_ip_on_master_eni
  reject_unsupported_control_plane_virtual_ip_mode
  reject_unknown_control_plane_virtual_ip_owner
  reject_non_master_control_plane_virtual_ip_owner
  reject_control_plane_virtual_ip_with_source_dest_check
  reject_control_plane_virtual_ip_outside_owner_subnet
  reject_reserved_control_plane_virtual_ip
  reject_overlapping_control_plane_virtual_ip
  reject_overlapping_static_ip_ranges
  reject_static_ip_subnet_exhaustion
  plan_prod_image_catalog
  plan_dev_image_catalog
  reject_missing_customer_image
  plan_legacy_global_image_override
  plan_legacy_regional_image_override
  plan_workload_image_override_precedence
  reject_malformed_resolved_image
  reject_non_x86_64_image
  reject_unavailable_image
  plan_deduplicated_image_validation
  plan_catalog_nic_mappings
  plan_nic_mapping_overrides
  plan_global_nic_override
  plan_per_node_overrides
  plan_instance_create_timeout_precedence
  plan_default_instance_create_timeout
  reject_malformed_instance_create_timeout
  reject_unknown_instance_create_timeout_key
  reject_instance_type_missing_from_selected_az
  plan_deduplicated_exact_az_offering_lookup
  plan_hybrid_recording_create_new_bucket
  plan_hybrid_recording_use_existing_bucket
  plan_advanced_s3_bucket_modes
  plan_explicit_nodes_with_external_dependencies
  reject_duplicate_explicit_node_key
  reject_empty_explicit_private_ips
  reject_explicit_ip_outside_subnet
  reject_explicit_eips_without_private_ips
  reject_mixed_explicit_security_ownership
  reject_mixed_explicit_iam_ownership
  plan_generic_hybrid_recording_s3_access
  reject_conflicting_hybrid_recording_s3_inputs
  warn_deprecated_enable_least_privilege_egress
  warn_deprecated_subnet_cidrs
  warn_deprecated_instance_family_nic_map
  warn_deprecated_public_ipv4_on_boot
  warn_deprecated_hybrid_recording_s3_inputs
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

if ! rg --quiet 'Zoom Node AMIs are not public AWS Marketplace images' README.md; then
  echo "README must document the private Zoom Node AMI requirement." >&2
  exit 1
fi

if rg --quiet 'ami-[0-9a-f]{17}' image-catalog.json; then
  echo "The reusable image catalog must not contain private AMI IDs." >&2
  exit 1
fi

if ! rg --quiet 'image_ids[[:space:]]*=' examples/customer-ami-catalog/main.tf; then
  echo "The customer AMI catalog example is missing its image_ids configuration." >&2
  exit 1
fi

for example_dir in examples/*; do
  test -d "$example_dir" || continue
  rg --quiet 'max_retries[[:space:]]*=[[:space:]]*var\.aws_max_retries' "$example_dir/providers.tf" || {
    echo "$example_dir must configure provider max_retries." >&2
    exit 1
  }
  rg --quiet 'retry_mode[[:space:]]*=[[:space:]]*var\.aws_retry_mode' "$example_dir/providers.tf" || {
    echo "$example_dir must configure provider retry_mode." >&2
    exit 1
  }
  rg --quiet 'output "capacity_preflight_requests"' "$example_dir/outputs.tf" || {
    echo "$example_dir must forward capacity_preflight_requests." >&2
    exit 1
  }
done

printf 'All %d required Terraform contract runs are present.\n' "${#required_runs[@]}"
