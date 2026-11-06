# Terraform Apply Capacity Diagnostics Design

## Intent

Provide Zoom Node operators with a guarded Terraform apply command that explains common AWS provisioning failures in plain language and prevents predictable low-capacity launches before they create partial resources.

## Goals

- Run the existing Capacity Manager preflight against a saved Terraform plan before apply.
- Block scores below `medium` by default, with an explicit low-capacity override.
- Keep Capacity Manager optional by supporting an explicit preflight skip.
- Preserve Terraform output and its original exit status.
- Diagnose EC2 capacity, quota, subnet-address, Spot-limit, and unsupported-configuration errors.
- Never change an Availability Zone, instance type, subnet, or saved plan automatically.

## Non-goals

- Guarantee EC2 capacity or reserve it.
- Make Capacity Manager a module or Terraform prerequisite.
- Retry capacity failures indefinitely.
- Roll back resources Terraform created before a failed EC2 launch.

## Approach

Add `scripts/apply-with-diagnostics.sh` as an operator wrapper around the existing `check-ec2-capacity.sh` and `terraform apply` commands. A standalone wrapper is preferred over Terraform checks because provider errors cannot be intercepted or rewritten in HCL, and Capacity Manager requires optional account-level services. Automatic placement fallback is rejected because the module's managed ENIs, static addresses, subnets, and reviewed saved plans are Availability Zone specific.

The wrapper accepts a saved plan, defaults the minimum score to `medium`, and stops on low supportability. `--allow-low-capacity` permits an informed attempt, while `--skip-capacity-check` supports accounts without Capacity Manager. If apply fails, the wrapper classifies known AWS error codes, prints actionable context after the original Terraform output, and exits with Terraform's status.

## Constraints

- Bash 3.2-compatible implementation for macOS and Linux.
- No new runtime dependency beyond Terraform and the existing preflight dependencies.
- Temporary diagnostic logs must be permission-restricted and removed on exit.
- Saved plans remain sensitive and must not be inspected beyond the existing nonsensitive capacity output.

