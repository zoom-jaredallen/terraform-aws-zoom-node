# Workloads

`workload-catalog.json` is the source of truth for default capacity, compute, storage, private-IP, and Elastic IP requirements. Terraform callers can override sizing where a lab or approved exception requires it, but production deployments should follow current Zoom requirements.

## Default catalog

| Workload key | Default AWS type | vCPU | Memory | Root disk | Private IPs | Public-mode EIPs | Capacity model |
|---|---:|---:|---:|---:|---:|---:|---|
| `meetings_hybrid` | `c6i.2xlarge` | 8 | 16 GB | 200 GB | 5 | 5 | 400 concurrent private meeting attendees per node, minimum 2 |
| `hybrid_recording` | `m6i.6xlarge` | 24 | 96 GB | 200 GB | 5 | 1 | 30 simultaneous recordings per node, minimum 2 |
| `meeting_survivability` | `c6i.xlarge` | 4 | 8 GB | 200 GB | 5 | 1 | Explicit node count, minimum 1 |
| `web_application_gateway` | `c6i.2xlarge` | 8 | 16 GB | 200 GB | 5 | 1 | 200 concurrent web private meeting attendees per node, minimum 2 |
| `ai_services` | `g6.12xlarge` | 48 | 192 GB | 500 GB | 1 | 0 | Explicit node count, minimum 1 |
| `phone_local_survivability` | `c6i.2xlarge` | 8 | 16 GB | 200 GB | 5 | 1 | 5,000 phone registrations per node, minimum 2 |

Public-mode EIPs are attached to the first private IPs on a node ENI. The current AWS MVP rejects `private_cloud`; private-only topology support remains future work.

## Standard workload interface

Use `workloads` for Zoom products with catalog-backed capacity and defaults:

```hcl
workloads = {
  meetings_hybrid = {
    enabled  = true
    capacity = 500
  }
  meeting_survivability = {
    enabled    = true
    node_count = 1
  }
}
```

Sized workloads calculate node count from capacity and enforce their minimum. Use `node_count_override` only when Zoom design guidance requires an explicit count. Meeting Survivability and AI Services use `node_count` directly because their catalog entries are not capacity-sized.

Every workload supports approved overrides for instance type, AMI, root-volume size, private IP count, Elastic IP count, and starting private-IP offset.

## Advanced node groups

Use `node_groups` for heterogeneous infrastructure roles or lab topologies that do not follow a workload capacity formula. A group defines count, role, hostname prefix, instance type, storage, IP counts, subnet tier/index, purchase option, security profile, and IAM profile.

Advanced security profiles currently include `meetings_hybrid`, `kubernetes_master`, and `kubernetes_worker`. Kubernetes profiles allow internal cluster traffic; the master profile also allows management TCP and UDP from the configured management networks.

## Explicit nodes

Use `explicit_nodes` when each appliance must retain an exact Terraform key, hostname, private-IP list, security-group attachment, or IAM instance profile. This is the preferred adoption interface for pre-existing or manually addressed fleets.

Do not mix module-managed and externally managed security-group ownership on one explicit node. Likewise, choose either a module-managed IAM profile key or an external instance-profile name.

## AI Services

Supported catalog overrides are `g5.12xlarge`, `g6.12xlarge`, and `g7e.2xlarge`. Availability and Spot capacity vary significantly by Region and Availability Zone. Confirm GPU quota, instance offering, physical capacity, and AMI driver compatibility before applying.

## Sizing changes

Changing an instance type normally stops and starts an existing instance. Changing an AMI replaces it. Increasing a root volume is normally in-place; shrinking is unsupported. Always review the provider plan and provide a fresh registration code before any operation that adds or replaces nodes.
