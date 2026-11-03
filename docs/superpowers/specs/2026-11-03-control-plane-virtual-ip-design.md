# Control Plane Virtual IP Design

## Intent

Add a provider-neutral control-plane virtual IP contract. The AWS implementation assigns the address as a secondary private IPv4 address on one Kubernetes master's primary ENI so kube-vip can use it. A later implementation may assign the address to a managed load balancer that forwards to healthy control-plane nodes.

## Interface

```hcl
control_plane_virtual_ip = {
  address         = "10.20.0.250"
  assignment_mode = "node"
  owner_node_key  = "kubernetes_master-01"
}
```

`assignment_mode` defaults to `node`. This release accepts only `node`; the field is retained so a future release can add `load_balancer` plus backend-node and health-check settings without changing the meaning of existing configurations.

## Behavior

- Validate that the owner exists, has role `kubernetes_master`, has source/destination checking disabled, and uses a subnet containing the VIP.
- Reject malformed, reserved, or overlapping addresses.
- Add the VIP to the AWS ENI address list for the owner node.
- Keep the VIP out of appliance cloud-init and Elastic IP allocation. Kube-vip, rather than static guest networking, owns the address inside the appliance.
- Expose the normalized endpoint and owner ENI through a nonsensitive output.
- Preserve the existing ENI private-IP lifecycle rule used by adopted deployments. New ENIs receive the VIP automatically; existing ENIs require an explicit ENI and instance replacement so the change is deliberate and cloud-init credentials can be refreshed.

## Future Load Balancer

A later release may accept `assignment_mode = "load_balancer"`, backend master keys, and a health-check object. Provider implementations can then create a regional load balancer, assign its private frontend addresses, register master targets, and publish endpoint details through the same output. This release creates no load balancer and grants no runtime EC2 reassignment permissions.

## Approaches Considered

- **Compatible creation/replacement assignment (selected):** keeps adoption guarantees and uses only the AWS provider, with deliberate replacement for an existing owner ENI.
- **Remove ENI lifecycle protection:** allows in-place reconciliation but can remove externally managed addresses from existing clusters.
- **Local AWS CLI provisioner:** can mutate an existing ENI but makes the registry module depend on local tooling and credentials, and weakens destroy and drift behavior.

## Non-goals

- Automatic kube-vip failover between AWS ENIs.
- Load-balancer resources or target health checks in this release.
- Rendering the VIP as a static appliance address.
- Automatically replacing a running control-plane node when the input is added.
