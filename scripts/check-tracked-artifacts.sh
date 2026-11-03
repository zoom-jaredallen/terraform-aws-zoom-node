#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
found=false

while IFS= read -r -d '' tracked_file; do
  case "$tracked_file" in
    .env.example|*/.env.example)
      ;;
    .env|*/.env|.env.*|*/.env.*|*.tfstate|*.tfstate.*|tfplan|*/tfplan|*.tfplan|*.plan|local.auto.tfvars|*/local.auto.tfvars|*.tfvars.local|*/.migration/*)
      echo "Tracked sensitive or local Terraform artifact: $tracked_file" >&2
      found=true
      ;;
  esac
done < <(git -C "$repo_root" ls-files -z)

[[ "$found" == false ]]
