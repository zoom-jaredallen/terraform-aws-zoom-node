# Native Contract Coverage Design

## Intent

Expand the mocked, plan-only Terraform contract suite so every supported workload and the module's major deployment choices are exercised without creating AWS resources.

## Coverage

- Every catalog workload and its default node/resource shape.
- New and existing VPC modes.
- Single- and dual-AZ placement.
- Private subnet routing through a managed NAT Gateway.
- Global and per-group Spot selection.
- Production and development AMI catalog channels.
- Catalog, exact override, family override, and global NIC-name precedence.
- Static IP overlap and subnet-exhaustion rejection.
- Hybrid Recording and advanced IAM-profile S3 create/existing modes.
- Stable-key per-node AMI and source/destination-check overrides.

## Structure

Keep the existing `tests/module.tftest.hcl` focused on baseline, egress, and hardening behavior. Add separate workload, networking, image/override, and storage-mode contract files. Each file owns its mock-provider defaults and base variables so it can run independently with `terraform test -filter`.

Add a lightweight manifest check to the repository gate. The check asserts that named contract runs continue to exist, preventing a passing but accidentally narrowed test suite.

## Constraints

- Tests use `command = plan`; they must not contact or mutate AWS.
- No production Terraform behavior or public module interface changes.
- Assertions target resources and outputs rather than duplicating implementation locals where practical.
- Test data uses documentation CIDRs, mock AMIs, and non-secret bootstrap values.

