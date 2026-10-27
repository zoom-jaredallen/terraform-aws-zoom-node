#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

deployment_dir="$tmp_dir/deployment"
fake_bin="$tmp_dir/bin"
mkdir -p "$deployment_dir" "$fake_bin"

cat >"$fake_bin/terraform" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case " $* " in
  *" state pull "*) printf '%s\n' '{"version":4,"terraform_version":"1.7.0","serial":1,"lineage":"test-lineage","resources":[]}' ;;
  *" state list "*) exit 0 ;;
  *" show -json "*) printf '%s\n' '{"values":{"root_module":{"resources":[]}}}' ;;
  *) echo "unexpected terraform command: $*" >&2; exit 2 ;;
esac
EOF

cat >"$fake_bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *" sts get-caller-identity "* ]]; then
  printf '%s\n' '{"Account":"123456789012","Arn":"arn:aws:iam::123456789012:user/test","UserId":"test"}'
else
  printf '%s\n' '{}'
fi
EOF

chmod +x "$fake_bin/terraform" "$fake_bin/aws"

if PATH="$fake_bin:$PATH" "$repo_root/scripts/capture-deployment-baseline.sh" "$deployment_dir" >/dev/null 2>&1; then
  echo "Expected empty state to be rejected." >&2
  exit 1
fi

PATH="$fake_bin:$PATH" ALLOW_EMPTY_STATE=1 "$repo_root/scripts/capture-deployment-baseline.sh" "$deployment_dir" >/dev/null

test -f "$deployment_dir/.migration/pre-migration.tfstate"
test -f "$deployment_dir/.migration/pre-migration-addresses.txt"
test -f "$deployment_dir/.migration/baseline.json"

unexpected_files="$(find "$deployment_dir" -type f ! -path "$deployment_dir/.migration/*" -print)"
test -z "$unexpected_files" || {
  echo "Baseline script wrote outside .migration:" >&2
  echo "$unexpected_files" >&2
  exit 1
}

echo "Baseline capture contract passed."
