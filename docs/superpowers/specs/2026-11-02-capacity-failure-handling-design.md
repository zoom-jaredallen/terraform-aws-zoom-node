# EC2 Capacity Failure Handling Design

## Intent

Fail faster and provide useful capacity guidance when AWS cannot immediately launch a requested EC2 instance, especially scarce GPU types. Preserve Terraform's declarative resource ownership while giving operators an explicit preflight check before an expensive apply.

## Goals

- Bound AWS provider API retries in every maintained example and deployment root.
- Make EC2 instance creation timeout configurable globally and for selected nodes or groups.
- Validate that each instance type is offered in its selected Availability Zone before apply.
- Provide an optional EC2 Capacity Manager preflight that reports `high`, `medium`, or `low` supportability scores.
- Keep existing node identities, networking, AMIs, and state addresses unchanged.

## Non-Goals

- Do not promise that a supportability score guarantees a later launch.
- Do not automatically move a node to another subnet, Availability Zone, or instance type.
- Do not enable Capacity Manager or change the customer's AWS Support plan.
- Do not run AWS CLI commands from Terraform through the `external` provider or provisioners.
- Do not create billable Capacity Reservations in this enhancement.

## Provider Retry Ownership

Terraform child modules cannot configure the caller's AWS provider. Each executable root will therefore expose:

```hcl
variable "aws_max_retries" {
  type    = number
  default = 5
}

variable "aws_retry_mode" {
  type    = string
  default = "standard"
}

provider "aws" {
  region      = var.aws_region
  max_retries = var.aws_max_retries
  retry_mode  = var.aws_retry_mode
}
```

`aws_max_retries` must be a non-negative integer. `aws_retry_mode` must be `standard` or `adaptive`. Documentation will also mention the equivalent `AWS_MAX_ATTEMPTS` and `AWS_RETRY_MODE` environment variables for callers that cannot edit a provider block.

The default of `5` intentionally replaces the AWS provider default of `25` in maintained roots. It bounds the known `InsufficientInstanceCapacity` retry behavior while retaining retries for throttling and transient API failures.

## EC2 Create Timeout Interface

The reusable module will add the following AWS-specific settings:

```hcl
aws = {
  instance_create_timeout = "10m"
  node_instance_create_timeouts = {
    ai_services-01 = "5m"
    ai_services-02 = "5m"
  }
}
```

Advanced `node_groups` and `explicit_nodes` entries gain an optional `instance_create_timeout`. Resolution order is:

1. `aws.node_instance_create_timeouts[stable-node-key]`
2. Group or explicit-node `instance_create_timeout`
3. `aws.instance_create_timeout`

The global default remains `10m` for compatibility. The US West lab AI group will explicitly use `5m`. Timeout strings must be non-empty Terraform duration strings composed of hours, minutes, or seconds, such as `90s`, `5m`, or `1h30m`.

The private `node` implementation module will carry the resolved timeout in each normalized node record and apply it to:

```hcl
timeouts {
  create = each.value.instance_create_timeout
}
```

Provider retries and resource timeout are complementary. Provider retries limit repeated AWS API calls; the resource timeout limits the overall EC2 create operation where the provider honors its context deadline.

## Availability Zone Offering Validation

Replace region-only instance-type offering checks with deduplicated instance-type and selected-AZ pairs. Query `aws_ec2_instance_type_offerings` using `location_type = "availability-zone"`, and fail planning when a requested type is not offered in its exact target AZ.

This validates product availability, not live physical capacity. The error must say which type and AZ are unsupported and recommend another AZ or compatible type.

## Terraform Capacity Manifest

The reusable module will expose a nonsensitive `capacity_preflight_requests` output derived from the resolved node records:

```hcl
capacity_preflight_requests = [
  {
    region            = "us-west-2"
    availability_zone = "us-west-2b"
    instance_type      = "g5.12xlarge"
    market_type        = "on-demand"
    instance_count     = 2
  }
]
```

Requests are grouped by region, Availability Zone, instance type, and market type. The manifest must contain only the five fields above. It must not contain AMI IDs, registration codes, passwords, cloud-init, account IDs, subnet IDs, private IP addresses, or public IP addresses.

Every maintained executable root will forward the module output unchanged. This gives the preflight script a stable contract while leaving Terraform configuration parsing, module expansion, defaults, and overrides inside Terraform itself.

## Capacity Preflight

Add `scripts/check-ec2-capacity.sh`. Saved Terraform plan mode is the preferred interface:

```bash
terraform plan -out=tfplan
check-ec2-capacity.sh \
  --terraform-plan tfplan \
  [--capacity-manager-region us-west-2] \
  [--minimum-score medium] \
  [--output table|json]
```

The script runs `terraform show -json`, extracts only `.planned_values.outputs.capacity_preflight_requests.value`, validates the manifest schema, and discards the complete plan stream. It may use a permission-restricted temporary file for the extracted nonsensitive manifest, but must never retain or print the full plan JSON.

Manual mode remains available for ad hoc checks:

```text
check-ec2-capacity.sh \
  --region us-west-2 \
  [--capacity-manager-region us-west-2] \
  --market-type on-demand \
  --capacity 2 \
  --availability-zone us-west-2b \
  --instance-type g5.12xlarge \
  [--minimum-score medium] \
  [--output table|json]
```

`--terraform-plan` and the manual capacity arguments are mutually exclusive. In manual mode, `--region` identifies the target deployment region. `--capacity-manager-region` identifies the single Region where Capacity Manager is enabled. It defaults to the target region for a single-region manifest and is required for a multi-region manifest or when Capacity Manager is enabled in a different Region.

The script will:

1. Require AWS CLI v2 with the Capacity Manager supportability command and `jq`.
2. Confirm caller identity without printing credentials.
3. Translate account-specific AZ names to stable AZ IDs with `describe-availability-zones`.
4. Read Capacity Manager attributes and report actionable setup guidance when it is disabled or unavailable.
5. Group requests by market type and instance count, then call `get-capacity-manager-supportability-scores` for each compatible group.
6. Print the aggregate score and every type/AZ score as `high`, `medium`, or `low`.
7. Avoid persisting API output because AWS prohibits sharing real-time supportability results with third parties.

Multiple `--instance-type` and `--availability-zone` options are supported within AWS API limits. `--market-type` accepts `on-demand` or `spot`; capacity is measured in instances for this first version. Target AZ names are resolved in the deployment region, while score requests are sent through `--capacity-manager-region`. Grouping is required because the AWS API accepts one market type and one capacity amount per request.

Default behavior is informational and exits zero for any valid score. `--minimum-score` enables CI gating with ordering `low < medium < high`.

Exit codes:

| Code | Meaning |
|---|---|
| `0` | Scores returned and optional threshold met |
| `2` | Valid scores returned but below `--minimum-score` |
| `3` | Capacity Manager, support plan, IAM, AWS CLI, or API prerequisite failure |
| `64` | Invalid command-line usage |

Minimum IAM actions are `sts:GetCallerIdentity`, `ec2:DescribeAvailabilityZones`, `ec2:GetCapacityManagerAttributes`, and `ec2:GetCapacityManagerSupportabilityScores`.

## Operational Constraints

- Capacity Manager must be enabled in an account-level Region.
- Real-time supportability scores require AWS Support Unified Operations.
- Scores are point-in-time guidance and do not reserve or guarantee capacity.
- The script must not automatically enable Capacity Manager because that changes account-level service configuration.
- Saved Terraform plans and their JSON representation can contain secrets. Operators must protect the plan file as sensitive data even though the extracted capacity manifest is explicitly nonsensitive.
- A future, separate enhancement may add opt-in On-Demand Capacity Reservations for guaranteed launches.

## Release And Migration

Ship this together with the pending customer-owned AMI work as `v0.4.0`. Before updating stateful deployment roots, pass their existing AMI IDs through `image_ids` so the upgrade plan does not replace instances. Provider retry changes do not alter Terraform state. Timeout-only changes must not replace instances.

