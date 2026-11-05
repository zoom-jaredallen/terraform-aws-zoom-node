# Networking

## Network modes

| Mode | Module responsibility | Caller responsibility |
|---|---|---|
| `create_new` | VPC, selected subnet tiers, internet gateway, routes, and optional NAT Gateway | CIDR design, destination controls, account quotas, and upstream connectivity |
| `use_existing` | Node ENIs, private IPs, security groups, and EIPs | VPC, subnets, route tables, internet/NAT access, DNS, and network ACLs |

The current AWS MVP supports `deployment_mode = "public_cloud"`. Although the portable interface reserves `private_cloud`, validation rejects it until feature parity is implemented.

## Availability Zones and subnets

`single_az` uses one subnet index. `dual_az` distributes generated nodes across two indexes. Advanced groups and explicit nodes can set `subnet_index` to select an exact zero-based subnet without redistributing existing nodes.

For a new network, configure `public_subnet_cidrs` and `private_subnet_cidrs`, or allow the module to derive subnets from the VPC CIDR and `subnet_newbits`. For an existing network, provide `existing_vpc_id` and ordered `existing_subnet_ids`.

Private node groups currently require `network_mode = "create_new"`. Private groups that need outbound internet access can use `create_nat_gateway = true`. The module creates one NAT Gateway in the first public subnet and routes managed private subnets through it. This is not a multi-AZ high-availability NAT design.

## Bootstrap readiness

The module associates public Elastic IPs with standalone ENIs before starting EC2 instances. This ensures public nodes can reach Zoom registration services from their first boot rather than racing a post-launch EIP association.

After managed subnets, gateways, routes, and route-table associations converge, the module waits for `aws.network_stabilization_delay` before creating any node. The default is `90s`, allowing AWS network data-plane changes to propagate before the Zoom Node appliance begins its limited registration retry sequence. Private nodes continue to use NAT Gateway egress and do not require individual EIPs.

Use `0s` for an established existing VPC only when its egress path is already operational. Changing the network topology replaces the readiness barrier and reapplies the delay; ordinary instance updates do not repeatedly wait.

## Deterministic private IPs

Standard workloads reserve blocks using catalog start offsets. `private_ips_per_eni` is the total number of addresses on a node ENI, including its primary address. The module checks range boundaries and collisions during planning.

Advanced groups derive addresses from `private_ip_start_offset`; explicit nodes provide the complete list. Ensure the first address in an explicit-node list is intended to be primary.

## Elastic IPs

In public mode, EIPs are associated with the first N private addresses on each ENI. Workload defaults are documented in [Workloads](workloads.md). The module checks the applied regional Elastic IP quota. Invalid credentials or insufficient permission to read Service Quotas causes planning to fail rather than falling back to a default.

Elastic IPs belong to individual node keys. Reducing counts or renaming nodes releases the affected addresses.

## Control-plane virtual IP

Configure a provider-neutral control-plane VIP for kube-vip with an address and stable owner node key:

```hcl
control_plane_virtual_ip = {
  address         = "10.20.0.250"
  assignment_mode = "node"
  owner_node_key  = "kubernetes_master-01"
}
```

The owner must be a `kubernetes_master`, use the same subnet as the VIP, and set `source_dest_check = false`. Terraform rejects malformed, AWS-reserved, out-of-subnet, and overlapping addresses.

On AWS, the module adds the VIP to the owner's primary ENI but does not render it into cloud-init or associate an Elastic IP with it. Kube-vip owns the address inside the guest. AWS does not move a private address between ENIs in response to gratuitous ARP, so this mode does not provide reliable cross-master failover.

The portable `assignment_mode` field is reserved for future provider implementations. A later `load_balancer` mode can assign frontend addresses to a managed load balancer, register control-plane nodes as backends, and route only to nodes passing a configured health check.

## DNS and interface names

The module generates FQDNs but does not create DNS records. Configure the resulting public or private addresses in the caller's DNS system.

Cloud-init needs the guest-visible interface name. Resolution order is:

1. global `aws.network_interface_name`;
2. exact `aws.network_interface_names_by_instance_type` entry;
3. exact mapping in `instance-catalog.json`;
4. deprecated family-wide override when no exact mapping exists.

An unmapped instance type fails validation instead of defaulting silently. Add exact mappings for newly approved types after confirming the interface name in the corresponding Zoom Node image.

## Traffic sources

| Source input | Intended use |
|---|---|
| `zoom_clients` | Zoom clients and phones; defaults to `0.0.0.0/0` |
| `zoom_cloud` | Zoom Cloud destinations for workload-specific egress; defaults to `0.0.0.0/0` |
| `remote_management_1` | Primary administrator network |
| `remote_management_2` | Secondary administrator network |
| `internal_traffic` | VPC, Kubernetes, database, and other east-west traffic; defaults to the effective VPC CIDR when empty |
| `nfs` | Hybrid Recording NFS destinations |
| `sbc` | Phone Local Survivability SBC traffic |

All standard workload groups allow management TCP/8443 from both remote-management inputs. Keep management sources narrow. Workload ingress and egress are generated separately; see [Security](security.md).

## Existing-network checklist

- Subnet routes support every required public, NAT, peering, transit-gateway, or private-endpoint path.
- Network ACLs allow return traffic and ephemeral ports.
- DNS servers resolve Zoom and customer endpoints.
- The subnet has room for all requested private addresses.
- Existing security controls do not conflict with the module-managed groups.
- Cross-VPC NFS or internal traffic has symmetric routing; an internet path between public EIPs is not equivalent to VPC peering.
