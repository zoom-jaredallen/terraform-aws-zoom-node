# Frequently Asked Questions

## Is this a Terraform provider?

No. It is a Terraform module built on the official HashiCorp AWS and Random providers. Validation, catalogs, and cloud-init rendering belong to the module; AWS API behavior belongs to the provider.

## Where do I get the AMI IDs?

Obtain private Zoom Node images through the approved Zoom distribution process, then share or copy them into each customer account and Region. Populate the caller-owned `image_ids` map. The reusable module intentionally contains no private image IDs.

## Can production and development images coexist?

Yes. Store both channels in `image_ids`; `prod` remains the default. Select `dev` explicitly for an SSH-enabled development image, or use a per-node AMI override for a controlled canary.

## Does changing the registration code reboot or replace existing nodes?

No. Existing EC2 instances ignore bootstrap user-data drift. The new value is used only when Terraform creates or replaces a node. Always supply a fresh valid code before adding or replacing nodes.

## Can the module generate the node password?

Yes. Set `generate_node_password = true` and omit `node_password`. Retrieve it from the sensitive output and store it in an approved secret manager. The value still exists in Terraform state.

## Why does destroy ask for registration code and password inputs?

Terraform evaluates the root configuration before it can build a destroy plan. Required variables therefore still need syntactically valid values. Keep an ignored local variable file or inject `TF_VAR_*` values.

## Should I use Spot instances?

Only for disposable environments that tolerate interruption. AWS can reclaim Spot instances with short notice, Terraform does not replace one until the next apply, and a replacement Zoom Node may require a fresh registration code. On-Demand or reserved capacity is more appropriate for persistent service nodes.

## Can the module deploy private-only nodes?

Not yet. The portable interface reserves `private_cloud`, but the current AWS MVP rejects it. Advanced public deployments can place selected node groups in private subnets behind a NAT Gateway while other groups remain public.

## How are IP addresses allocated?

Standard workloads derive deterministic blocks from the workload catalog. Advanced groups use a start offset. Explicit nodes supply the full address list. Elastic IPs attach to the first N private addresses on a node ENI.

## Can I use external security groups or IAM roles?

Yes, through `explicit_nodes`. Supply either module-managed profile keys or external IDs/names for each ownership domain, but do not mix both forms on one node.

## Does the module create DNS records?

No. It outputs node FQDNs and addresses; the caller owns DNS zones and records.

## Can the module check EC2 capacity before apply?

It checks exact-AZ instance offerings during plan. The optional `check-ec2-capacity.sh` script can query EC2 Capacity Manager and assign a supportability score from a saved plan. Neither method reserves capacity.

## Is the capacity script cross-platform?

It is a Bash script for Linux and macOS. On Windows, run it in WSL or a compatible Bash environment with AWS CLI v2 and `jq` installed.

## How should production releases be consumed?

Use an immutable semantic-version Git tag. Terraform Registry publication is currently deferred, so the documented module source remains the GitHub URL pinned with `?ref=vX.Y.Z`.
