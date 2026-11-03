#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="$repo_root/scripts/check-tracked-artifacts.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

git -C "$test_root" init -q
git -C "$test_root" config user.email test@example.com
git -C "$test_root" config user.name Test
printf '.env\n*.tfstate\n' >"$test_root/.gitignore"
printf 'safe\n' >"$test_root/main.tf"
printf 'local-secret\n' >"$test_root/.env"
git -C "$test_root" add .gitignore main.tf

"$checker" "$test_root"

git -C "$test_root" add -f .env
if "$checker" "$test_root"; then
  echo "FAIL: tracked .env was accepted" >&2
  exit 1
fi

git -C "$test_root" reset -q .env
printf 'state\n' >"$test_root/terraform.tfstate"
git -C "$test_root" add -f terraform.tfstate
if "$checker" "$test_root"; then
  echo "FAIL: tracked Terraform state was accepted" >&2
  exit 1
fi

echo "Tracked artifact policy tests passed"
