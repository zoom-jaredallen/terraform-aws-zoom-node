#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

terraform fmt -check -recursive .
terraform-docs --config .terraform-docs.yml --output-check .
tflint --config="$repo_root/.tflint.hcl" --init
tflint --config="$repo_root/.tflint.hcl" --minimum-failure-severity=warning
terraform init -backend=false -input=false
terraform validate
terraform test

while IFS= read -r dir; do
  terraform -chdir="$dir" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$dir" validate
  tflint --config="$repo_root/.tflint.hcl" --chdir="$dir" --minimum-failure-severity=warning
done < <(find examples -mindepth 1 -maxdepth 1 -type d | sort)

trivy config --severity HIGH,CRITICAL --exit-code 1 --ignorefile .trivyignore.yaml .
trivy fs --scanners secret --exit-code 1 .

if find . -name .git -type d -prune -o -name .terraform -type d -prune -o -type f \( -name '*.tfstate' -o -name '*.tfstate.*' -o -name '*.tfplan' -o -name '*.plan' -o -name 'local.auto.tfvars' -o -name '*.tfvars.local' -o -name '.env' -o \( -name '.env.*' ! -name '.env.example' \) \) -print | grep -q .; then
  echo "Sensitive or local Terraform artifacts are present." >&2
  exit 1
fi
