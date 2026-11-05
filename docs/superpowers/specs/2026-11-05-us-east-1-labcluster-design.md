# US East Lab Cluster Design

## Intent

Add a disposable `us-east-1` Terraform deployment for one Meetings Hybrid node, three Kubernetes masters, four Kubernetes workers, and one `g6.12xlarge` AI worker. The user will supply a fresh Zoom Node registration code and run the plan and apply.

## Selected Approach

Use the maintained deployment-root pattern and the in-repository module until the post-`v0.4.1` managed-EIP quota fix receives an immutable release. Create a new VPC with public subnets for Meetings Hybrid and masters and NAT-backed private subnets for workers and AI Services.

The initial single-AZ layout failed because `us-east-1a` had insufficient `g6.12xlarge` capacity. Preserve all successful CPU nodes in `us-east-1a` and add a dedicated `us-east-1b` private subnet for only the GPU worker.

## Configuration

- Region and AZs: `us-east-1`; CPU nodes in `us-east-1a`, GPU in `us-east-1b`.
- Network: new `10.40.0.0/16` VPC with `10.40.0.0/24` public, `10.40.1.0/24` CPU-private, and `10.40.2.0/24` GPU-private subnets.
- Images: production `ami-012f8220608dbc5fb`; development `ami-084ef071e238208e7`.
- Development image: Kubernetes masters only.
- Production image: Meetings Hybrid, Kubernetes workers, and AI Services.
- Purchase option: On-Demand for every node because current Spot supportability is low.
- Credentials: generate the node password; keep the registration code in ignored `local.auto.tfvars`.
- GPU networking: use `enp39s0` for `g6.12xlarge`.
- Storage access: create an account-qualified S3 bucket and grant the Kubernetes profile access.
- Remote management: retain the maintained lab default `180.150.42.155/32`.

## Constraints

- Both copied AMIs must reach `available` before planning.
- No EC2 instances are created by this change.
- State, saved plans, credentials, and live registration values remain untracked.
- The Capacity Manager preflight is advisory and is expected to report low while `g6.12xlarge` capacity remains constrained.

