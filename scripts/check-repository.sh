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
./scripts/check-test-contract-coverage.sh
./scripts/check-module-extraction.sh
./scripts/test-capture-deployment-baseline.sh
./scripts/test-check-ec2-capacity.sh
./scripts/test-check-tracked-artifacts.sh
terraform test

while IFS= read -r dir; do
  terraform -chdir="$dir" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$dir" validate
  tflint --config="$repo_root/.tflint.hcl" --chdir="$dir" --minimum-failure-severity=warning
  if [[ -d "$dir/tests" ]]; then
    terraform -chdir="$dir" test
  fi
done < <(find examples deployments -mindepth 1 -maxdepth 1 -type d | sort)

trivy config --severity HIGH,CRITICAL --exit-code 1 --ignorefile .trivyignore.yaml --tf-exclude-downloaded-modules .
trivy fs --scanners secret --exit-code 1 \
  --skip-dirs '**/.terraform' \
  --skip-dirs '**/.migration' \
  --skip-files '.env' \
  --skip-files '.env.*' \
  --skip-files '*.tfstate' \
  --skip-files '*.tfstate.*' \
  --skip-files 'tfplan' \
  --skip-files '*.tfplan' \
  --skip-files '*.plan' \
  --skip-files 'local.auto.tfvars' \
  --skip-files '*.tfvars.local' \
  .

./scripts/check-tracked-artifacts.sh
