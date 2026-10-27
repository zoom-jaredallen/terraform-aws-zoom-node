#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 DEPLOYMENT_DIR" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage

deployment_dir="$(cd "$1" && pwd)"
migration_dir="$deployment_dir/.migration"
state_file="$migration_dir/pre-migration.tfstate"
addresses_file="$migration_dir/pre-migration-addresses.txt"
show_file="$migration_dir/pre-migration-show.json"
baseline_file="$migration_dir/baseline.json"

mkdir -p "$migration_dir"
terraform -chdir="$deployment_dir" state pull >"$state_file"
terraform -chdir="$deployment_dir" state list >"$addresses_file"

if [[ ! -s "$addresses_file" && "${ALLOW_EMPTY_STATE:-0}" != "1" ]]; then
  echo "Refusing to capture an empty Terraform state. Set ALLOW_EMPTY_STATE=1 only when the deployment is intentionally empty." >&2
  exit 1
fi

terraform -chdir="$deployment_dir" show -json "$state_file" >"$show_file"

aws_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
if [[ -z "$aws_region" ]]; then
  aws_region="$(aws configure get region 2>/dev/null || true)"
fi

identity_json="$(aws sts get-caller-identity --output json)"

jq \
  --arg deployment "$(basename "$deployment_dir")" \
  --arg region "$aws_region" \
  --argjson identity "$identity_json" \
  --slurpfile state "$state_file" '
  def modules:
    . as $module
    | $module,
      ($module.child_modules[]? | modules);
  def selected_values:
    . as $v
    | {
        id: $v.id,
        arn: $v.arn,
        name: ($v.name // $v.bucket // null),
        name_tag: ($v.tags.Name // null),
        instance_type: $v.instance_type,
        ami: $v.ami,
        private_ip: $v.private_ip,
        private_ips: $v.private_ips,
        public_ip: $v.public_ip,
        allocation_id: $v.allocation_id,
        subnet_id: $v.subnet_id,
        vpc_id: $v.vpc_id,
        security_groups: $v.security_groups,
        iam_instance_profile: $v.iam_instance_profile,
        source_dest_check: $v.source_dest_check,
        root_volume: ($v.root_block_device // null)
      }
    | with_entries(select(.value != null));
  {
    captured_at: (now | todateiso8601),
    deployment: $deployment,
    aws: {
      account: $identity.Account,
      principal_arn: $identity.Arn,
      region: $region
    },
    state: {
      serial: $state[0].serial,
      lineage: $state[0].lineage,
      terraform_version: $state[0].terraform_version
    },
    resources: [
      .values.root_module
      | modules
      | .resources[]?
      | select(.mode == "managed")
      | {
          address,
          type,
          name,
          index,
          values: (.values | selected_values)
        }
    ]
  }' "$show_file" >"$baseline_file"

instance_ids=($(jq -r '.resources[] | select(.type == "aws_instance") | .values.id // empty' "$baseline_file"))
eni_ids=($(jq -r '.resources[] | select(.type == "aws_network_interface") | .values.id // empty' "$baseline_file"))
allocation_ids=($(jq -r '.resources[] | select(.type == "aws_eip") | .values.id // .values.allocation_id // empty' "$baseline_file"))
security_group_ids=($(jq -r '.resources[] | select(.type == "aws_security_group") | .values.id // empty' "$baseline_file"))
vpc_ids=($(jq -r '.resources[] | select(.type == "aws_vpc") | .values.id // empty' "$baseline_file"))
subnet_ids=($(jq -r '.resources[] | select(.type == "aws_subnet") | .values.id // empty' "$baseline_file"))

aws_args=(--output json)
[[ -z "$aws_region" ]] || aws_args+=(--region "$aws_region")

((${#instance_ids[@]} == 0)) || aws ec2 describe-instances "${aws_args[@]}" --instance-ids "${instance_ids[@]}" >"$migration_dir/aws-instances.json"
((${#eni_ids[@]} == 0)) || aws ec2 describe-network-interfaces "${aws_args[@]}" --network-interface-ids "${eni_ids[@]}" >"$migration_dir/aws-network-interfaces.json"
((${#allocation_ids[@]} == 0)) || aws ec2 describe-addresses "${aws_args[@]}" --allocation-ids "${allocation_ids[@]}" >"$migration_dir/aws-addresses.json"
((${#security_group_ids[@]} == 0)) || aws ec2 describe-security-groups "${aws_args[@]}" --group-ids "${security_group_ids[@]}" >"$migration_dir/aws-security-groups.json"
((${#vpc_ids[@]} == 0)) || aws ec2 describe-vpcs "${aws_args[@]}" --vpc-ids "${vpc_ids[@]}" >"$migration_dir/aws-vpcs.json"
((${#subnet_ids[@]} == 0)) || aws ec2 describe-subnets "${aws_args[@]}" --subnet-ids "${subnet_ids[@]}" >"$migration_dir/aws-subnets.json"

echo "Captured redacted baseline: $baseline_file"
