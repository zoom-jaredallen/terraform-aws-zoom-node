# AMI Management

Zoom Node AMIs are private and are not currently published as public AWS Marketplace images. Every customer must supply image IDs visible to the account and Region where Terraform runs.

## Recommended customer catalog

Store production and optional development images in caller-owned configuration:

```hcl
image_channel = "prod"

image_ids = {
  prod = {
    us-west-2      = "ami-0123456789abcdef0"
    ap-southeast-2 = "ami-0fedcba9876543210"
  }
  dev = {
    us-west-2 = "ami-00112233445566778"
  }
}
```

`prod` is the default channel. Select `dev` explicitly only for a development image that supports SSH access. The reusable module's `image-catalog.json` is intentionally empty so it cannot expose or accidentally select private vendor images.

See [`examples/customer-ami-catalog`](../examples/customer-ami-catalog) for a copyable caller-owned pattern. Maintained deployments use `deployments/aws-ami-catalog.json`; that file is not consumed by external module callers.

## Selection precedence

AMI selection uses the following order, highest first:

1. `node_image_ids[stable-node-key]`.
2. A standard workload's `image_id`.
3. An advanced group or explicit node's `image_id`.
4. Customer `image_ids[channel][region]`.
5. Compatibility override `aws.image_id`.
6. Legacy regional `aws.image_ids[region]`.
7. Bundled `image-catalog.json`, currently empty.

Per-node overrides are useful during controlled image canaries. Keep the stable node key unchanged so only the intended instance is replaced.

## Image requirements

The selected AMI must:

- be visible to the active AWS account;
- exist in the provider's Region and be in the `available` state;
- use `x86_64` architecture;
- support the selected instance type and GPU generation;
- contain the correct Zoom Node software and cloud-init integration;
- have KMS permissions that allow the target account to launch it.

Terraform validates visibility, state, and architecture during planning. It cannot validate Zoom appliance compatibility or NVIDIA driver support.

## Multi-account and multi-Region distribution

Choose one controlled process:

- share an AMI and its backing KMS key with each customer account;
- copy the AMI into each customer account; or
- use an internal image pipeline to copy and record approved images per Region.

AMI IDs are regional. Copies receive new IDs, so a catalog must key values by Region. Treat AMI updates as reviewed releases and record their provenance outside Terraform.

## Update impact

Changing a selected AMI replaces every affected EC2 instance. Existing private IPs and EIPs remain associated through their separately managed ENIs, but the Zoom Node appliance boots again and needs a fresh registration code. Review the saved plan and schedule a maintenance window.

If only newly added nodes should use a new image, set `node_image_ids` for their stable keys first. Move the shared channel after the existing fleet is ready for replacement.
