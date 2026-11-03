# Terraform AWS Zoom Node

An AWS-native Terraform module for deploying Zoom Node workloads.

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.7-844FBA.svg)](https://www.terraform.io/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Documentation

| Guide | Purpose |
|---|---|
| [Getting started](docs/getting-started.md) | First plan, capacity preflight, apply, verification, and destroy |
| [Prerequisites](docs/prerequisites.md) | AWS identity, private AMIs, quotas, networking, and tools |
| [Architecture](docs/architecture.md) | Public facade, private implementation modules, catalogs, and ownership |
| [Workloads](docs/workloads.md) | Supported workload defaults, capacity, sizing, and node interfaces |
| [Networking](docs/networking.md) | VPC modes, subnets, IPs, EIPs, NAT, DNS, and traffic sources |
| [AMI management](docs/ami-management.md) | Customer image channels, precedence, distribution, and updates |
| [Security](docs/security.md) | State protection, firewall profiles, IAM, KMS, IMDSv2, and logs |
| [Upgrading](docs/terraform-upgrades.md) | Compatibility guarantees, imports, moves, and replacement triggers |
| [Troubleshooting](docs/troubleshooting.md) | Capacity, quota, bootstrap, registration, NFS, and state failures |
| [FAQ](docs/faq.md) | Common design and operation questions |

See the complete [documentation index](docs/README.md) and [Registry-readiness checklist](docs/registry-readiness.md).

## Prerequisites

- Terraform `>= 1.7.0`, AWS provider `>= 6.0`, and Random provider `>= 3.6`.
- A private Zoom Node AMI visible in the target AWS account and Region.
- A fresh Zoom Node registration code and either a compliant password or generated-password mode.
- AWS quotas, subnets, routing, and management CIDRs sized for the selected workloads.

Read [Prerequisites](docs/prerequisites.md) before the first plan. Terraform state and saved plans contain rendered bootstrap secrets and must be stored accordingly.

## Usage

```hcl
module "zoom_node" {
  source = "git::https://github.com/zoom-jaredallen/terraform-aws-zoom-node.git?ref=v0.4.0"

  environment_name       = "demo"
  domain_name            = "lab.example.com"
  deployment_mode        = "public_cloud"
  network_mode           = "create_new"
  registration_code      = var.registration_code
  generate_node_password = true

  image_ids = {
    prod = {
      us-west-2 = var.prod_ami_id
    }
  }

  source_cidrs = {
    remote_management_1 = ["203.0.113.10/32"]
    internal_traffic    = ["10.0.0.0/16"]
  }

  workloads = {
    meetings_hybrid = {
      enabled  = true
      capacity = 500
    }
  }

  aws = {
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["us-west-2a"]
  }
}
```

## Examples

| Example | Purpose |
|---|---|
| [Single-node smoke test](examples/aws-smoke-single-node) | Smallest live AWS validation |
| [New VPC](examples/aws-new-vpc) | Module-managed network and multiple workloads |
| [Existing VPC](examples/aws-existing-vpc) | Nodes deployed into caller-managed networking |
| [Customer AMI catalog](examples/customer-ami-catalog) | Production/development image channels owned by the customer |

Examples create billable AWS resources when applied. Copy their ignored local variable file, authenticate to the intended account, review a saved plan, and destroy short-lived tests when complete.

## Scope

Supported in this MVP:

- Meetings Hybrid
- Hybrid Recording
- Meeting Survivability
- Web Application Gateway
- AI Services
- Phone Local Survivability
- New VPC or existing VPC deployment
- Public cloud deployment mode, with `private_cloud` reserved for a later parity pass
- Workload-specific security groups
- Standalone ingress and egress rules with per-profile `allow_all`, `workload_specific`, or `deny_all` egress
- Hybrid Recording S3 bucket creation or existing-bucket access
- Optional customer-managed KMS keys, CloudWatch Logs retention, S3 versioning, and S3 lifecycle expiration
- On-Demand instances by default, with opt-in Spot instances for disposable lab environments
- One ENI per node with workload-specific private IP and Elastic IP counts
- Plan-time validation for customer AMI visibility, Zoom bootstrap values, management CIDRs, selected workload capacity, Elastic IP mapping, and regional Elastic IP quota
- Advanced heterogeneous node groups with per-group images, sizing, subnet tiers, Spot selection, IMDS settings, security profiles, and shared IAM profiles
- Public and private subnet tiers with optional NAT Gateway egress
- Bucket-scoped S3 access shared by one or more advanced IAM profiles

The public interface uses portable names such as `deployment_mode`, `network_mode`, `workloads`, and `source_cidrs`. AWS-specific values live inside the `aws` object so Azure, GCP, OCI, and Crossplane implementations can reuse the higher-level deployment contract later.

The published root module is a compatibility facade over three private, flat implementation modules: `network`, `node`, and `storage-access`. Consumers should continue calling only the repository root. The facade owns validation and normalization while the child modules own AWS resources; declarative state moves preserve existing deployments across this internal refactor.

Use `node_groups` for infrastructure roles or heterogeneous lab topologies that do not belong in the Zoom workload capacity catalog. Groups normalize into the same EC2, ENI, Cloud Init, EIP, and output path as `workloads`. Their `subnet_tier` selects a public or private subnet, and groups with the same `iam_profile_key` share one IAM role and instance profile.

Use `explicit_nodes` when adopting an existing deployment or when each appliance must retain an exact Terraform key, hostname, private-IP list, security-group attachment, or IAM instance profile. Explicit nodes share the normal EC2, ENI, Cloud Init, EIP, logging, and output paths, but they do not derive identities or addresses from counts and offsets. A node may select either a module-managed `security_profile` or external `security_group_ids`, and either a module-managed `iam_profile_key` or external `iam_instance_profile_name`; mixing ownership for the same node is rejected.

```hcl
explicit_nodes = {
  jp01worker1-ap-northeast-1a = {
    fqdn                      = "jp01worker1-ap-northeast-1a"
    role                      = "ai_services"
    instance_type             = "g6.12xlarge"
    image_id                  = "ami-0123456789abcdef0"
    root_volume_gb            = 500
    private_ips               = ["10.2.101.241"]
    subnet_tier               = "public"
    security_group_ids        = ["sg-0123456789abcdef0"]
    iam_instance_profile_name = "ZoomNodeS3Access"
  }
}
```

An advanced group can set `subnet_index` to select a specific zero-based subnet and Availability Zone within its tier. Omitting it preserves the existing single-AZ or round-robin placement behavior. When a higher index is selected with `network_mode = "create_new"`, the module expands only that subnet tier, so existing groups retain their current subnet indexes and are not redistributed.

Set `aws.create_nat_gateway = true` when private groups need outbound access. The module creates one NAT Gateway in the first public subnet and routes private-subnet IPv4 traffic through it. Use `aws.s3_bucket_access` to create or reference named buckets and grant bucket-scoped actions to selected IAM profile keys.

Hybrid Recording storage uses the same generic interface. Use the stable `hybrid_recording` access key and target the workload's `HybridRecording` IAM profile:

```hcl
aws = {
  s3_bucket_access = {
    hybrid_recording = {
      bucket_name      = "example-zoom-node-recordings"
      mode             = "create_new"
      iam_profile_keys = ["HybridRecording"]
    }
  }
}
```

The compatibility inputs `enable_least_privilege_egress`, `aws.subnet_cidrs`, `aws.network_interface_names_by_instance_family`, `aws.enable_public_ipv4_on_boot`, and the dedicated `hybrid_recording_s3_*` settings are deprecated for removal in `v1.0.0`. They remain functional in the `v0.x` line and emit Terraform check warnings with direct replacement guidance. Do not configure both generic and dedicated Hybrid Recording storage.

Set `aws.security_group_egress_profiles` by workload or advanced security-profile key to choose `allow_all`, `workload_specific`, or `deny_all`. Existing configurations keep unrestricted egress by default. `enable_least_privilege_egress` is deprecated but remains supported for compatibility.

Customer-managed KMS key inputs reference externally managed keys. The caller is responsible for key policies. Versioning and lifecycle settings apply only to buckets created by this module. See [`docs/terraform-upgrades.md`](docs/terraform-upgrades.md) before upgrading an existing deployment, especially for the one-time inline-to-standalone security-rule migration.

## Example

```hcl
module "zoom_node" {
  source = "git::https://github.com/zoom-jaredallen/terraform-aws-zoom-node.git?ref=v0.4.0"

  environment_name  = "demo"
  domain_name       = "lab.example.com"
  deployment_mode   = "public_cloud"
  network_mode      = "create_new"
  registration_code = var.registration_code
  generate_node_password = true

  image_ids = {
    prod = {
      us-west-2 = var.prod_ami_id
    }
  }

  source_cidrs = {
    zoom_clients        = ["0.0.0.0/0"]
    zoom_cloud          = ["0.0.0.0/0"]
    remote_management_1 = ["203.0.113.10/32"]
    internal_traffic    = ["10.0.0.0/16"]
    nfs                 = ["10.10.0.0/16"]
  }

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

  aws = {
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["us-west-2a"]
    purchase_option    = "on_demand"
  }
}
```

## Notes

The [`deployments`](deployments) directory contains maintained, environment-specific executable roots. These configurations are intentionally tracked because they document stable node identities, network placement, and upgrade behavior. They consume immutable module tags rather than the repository working tree. Never commit their state, saved plans, `.terraform` directories, `.env` files, or `local.auto.tfvars`; the repository ignore rules cover these operational artifacts while retaining dependency lock files.

Terraform stores rendered user data in state. Treat the state backend as sensitive because `registration_code` and `node_password` are rendered into cloud-init.

Set `generate_node_password = true` to let the module create a compliant 16-character password. In this mode, omit `node_password` and retrieve the result with `terraform output -raw generated_node_password`. To supply a password instead, leave generation disabled and pass `node_password` through a sensitive variable or `TF_VAR_node_password`. Terraform rejects configurations that select both methods or neither method.

Start with [`examples/aws-smoke-single-node`](examples/aws-smoke-single-node) when testing in a real AWS account. It deploys one Meeting Survivability node and exercises the same network, ENI, security group, Elastic IP, and user-data paths with a smaller blast radius.

The module reads the EC2 regional Elastic IP quota and existing EIP allocations during planning. Public cloud deployments fail early when the selected workloads need more Elastic IPs than the account can allocate in the target region.

Zoom Node AMIs are not public AWS Marketplace images. Before planning, obtain an AMI that is visible to the target AWS account in every deployment region. The AMI may be copied into the customer account or explicitly shared with it; AMI IDs are regional and a copied image receives a different ID.

The reusable module intentionally ships an empty `image-catalog.json`. Supply customer-accessible images through the top-level `image_ids` input, grouped by `prod` or `dev` channel and then AWS region. `image_channel` defaults to `prod`; select `dev` only for an SSH-enabled development image. Terraform queries every selected AMI during planning and rejects images that are not visible, not available, or not `x86_64`.

```hcl
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

AMI selection uses this precedence, from highest to lowest:

1. `node_image_ids` entry keyed by the stable Terraform node key, such as `meetings_hybrid-01`.
2. Workload-specific `image_id`.
3. Customer `image_ids` entry for the node's channel and AWS region.
4. Global `aws.image_id` compatibility override.
5. Legacy regional `aws.image_ids` compatibility entry.
6. The selected bundled `image-catalog.json` channel and AWS region, currently empty.

For example, this selects the customer development image generally while replacing one generated node with a specific AMI:

```hcl
image_channel = "dev"

image_ids = {
  dev = {
    us-west-2 = "ami-00112233445566778"
  }
}

node_image_ids = {
  meetings_hybrid-01 = "ami-0123456789abcdef0"
}
```

See [`examples/customer-ami-catalog`](examples/customer-ami-catalog) for a copyable customer-owned catalog. Existing `aws.image_id` and `aws.image_ids` configurations remain supported, but new deployments should use `image_ids` so production and development images can be managed independently.

Workload sizing, capacity, storage, IP allocation, and provider instance recommendations live in `workload-catalog.json`. The module derives its AWS defaults from that catalog while keeping workload-specific Terraform overrides available for exceptional deployments.

AI Services defaults to `g6.12xlarge` with a 500 GB root volume, one private IP, and no Elastic IPs. It also supports `g5.12xlarge` for four NVIDIA A10G GPUs and `g7e.2xlarge` as overrides. The module validates selected EC2 instance types against the current AWS region during planning because GPU-backed families are not available in every region or Availability Zone. Confirm that the selected Zoom Node AMI contains a compatible NVIDIA driver before changing GPU generations.

Cloud-init network interface names are selected by exact EC2 instance type from `instance-catalog.json`. Use `aws.network_interface_names_by_instance_type` to add or replace an exact mapping, the legacy `aws.network_interface_names_by_instance_family` override for a family-wide mapping, or `aws.network_interface_name` to force one interface name for all nodes. An unmapped instance type fails validation instead of silently defaulting to an interface that may not exist.

EC2 instances enforce IMDSv2 and use an HTTP PUT response hop limit of `3` by default. Override `aws.metadata_http_put_response_hop_limit` only when the guest networking model requires another AWS-supported value from 1 through 64.

Source/destination checking defaults to `true`. Kubernetes control-plane nodes that host a kube-vip virtual IP can disable it by stable Terraform node key:

```hcl
aws = {
  node_source_dest_check = {
    meetings_hybrid-01 = false
  }
}
```

Use `aws.instance_tags` for optional EC2-only tags. These tags are not applied to ENIs, security groups, log groups, storage, or networking resources. Module-generated identity tags such as `Name` and `ZoomNodeName` take precedence over custom values.

`aws.purchase_option` defaults to `on_demand`. Set it to `spot` only for disposable development and test environments that can tolerate interruption. AWS can terminate a Spot instance with two minutes' notice. Terraform does not replace an interrupted node until the next apply, and a replacement Zoom Node may need a fresh registration code because registration codes expire. Spot pricing affects EC2 compute only; EBS volumes, public IPv4 addresses, snapshots, and data transfer retain their normal charges.

### EC2 capacity failure handling

The module validates that every selected instance type is offered in its exact Availability Zone. This catches unsupported type/AZ combinations during planning, but it does not prove that AWS has enough physical capacity for a launch.

EC2 instance creation has a `10m` default timeout. Override `aws.instance_create_timeout`, an advanced group or explicit node's `instance_create_timeout`, or `aws.node_instance_create_timeouts[stable-node-key]`. Stable-node overrides take highest precedence. Executable roots own provider retries; the maintained examples default to `max_retries = 5` and `retry_mode = "standard"`. Callers can instead use `AWS_MAX_ATTEMPTS` and `AWS_RETRY_MODE` where editing the provider block is impractical.

For a point-in-time capacity score, create a saved plan and pass it to the preflight script:

```bash
terraform plan -out=tfplan
scripts/check-ec2-capacity.sh \
  --terraform-plan tfplan \
  --minimum-score medium
terraform apply tfplan
rm -f tfplan
```

The script reads the nonsensitive `capacity_preflight_requests` output from the saved plan, groups requests by market and node count, translates account-specific AZ names to stable AZ IDs, and reports `high`, `medium`, or `low`. Use `--capacity-manager-region` when Capacity Manager is enabled outside the deployment Region or the plan targets multiple Regions. Manual mode is also available:

```bash
scripts/check-ec2-capacity.sh \
  --region us-west-2 \
  --market-type on-demand \
  --capacity 2 \
  --availability-zone us-west-2b \
  --instance-type g5.12xlarge
```

The check requires AWS CLI v2.39.1 or newer, `jq`, account-level EC2 Capacity Manager, and AWS Support Unified Operations for real-time supportability. Minimum IAM actions are `sts:GetCallerIdentity`, `ec2:DescribeAvailabilityZones`, `ec2:GetCapacityManagerAttributes`, and `ec2:GetCapacityManagerSupportabilityScores`. Scores are guidance, not reservations or launch guarantees. Proceed on `high`; for `medium` or `low`, add compatible instance types or AZs, reduce the request, or retry later. Do not publish score responses.

Saved Terraform plans can contain the registration code, generated password, and rendered cloud-init even though the extracted capacity manifest is nonsensitive. Store plans with restricted permissions and delete them after review.

Reserved Instances and Savings Plans are billing commitments applied to matching On-Demand usage, so they are not module deployment options. Capacity Reservations and Dedicated Hosts have separate placement and lifecycle requirements and are outside this MVP.

`deployment_mode = "private_cloud"` is reserved in the interface for future parity work. The AWS Terraform MVP currently rejects it during planning because NAT gateway and private-only routing behavior has not been implemented yet.

For existing VPC deployments, this MVP still assigns deterministic private IPs so Elastic IPs can be attached to specific primary and secondary private addresses. Choose non-overlapping workload offsets before applying in shared subnets.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.7.0 |
| aws | >= 6.0 |
| random | >= 3.6 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0 |
| random | >= 3.6 |
| terraform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [random_password.node](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [terraform_data.validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_ami.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_ec2_instance_type_offerings.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type_offerings) | data source |
| [aws_eips.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eips) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_servicequotas_service_quota.ec2_elastic_ips](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/servicequotas_service_quota) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| availability\_zone\_config | Node placement model. | `string` | `"single_az"` | no |
| aws | AWS-specific settings kept behind the portable Zoom Node interface. | <pre>object({<br/>    image_id                                                         = optional(string, "")<br/>    image_ids                                                        = optional(map(string), {})<br/>    key_name                                                         = optional(string, null)<br/>    vpc_cidr                                                         = optional(string, "10.0.0.0/16")<br/>    subnet_cidrs                                                     = optional(list(string), [])<br/>    public_subnet_cidrs                                              = optional(list(string), [])<br/>    private_subnet_cidrs                                             = optional(list(string), [])<br/>    create_nat_gateway                                               = optional(bool, false)<br/>    availability_zones                                               = optional(list(string), [])<br/>    existing_vpc_id                                                  = optional(string, "")<br/>    existing_subnet_ids                                              = optional(list(string), [])<br/>    subnet_newbits                                                   = optional(number, 8)<br/>    dns_servers                                                      = optional(list(string), [])<br/>    network_interface_name                                           = optional(string, "")<br/>    network_interface_names_by_instance_type                         = optional(map(string), {})<br/>    network_interface_names_by_instance_family                       = optional(map(string), {})<br/>    metadata_http_put_response_hop_limit                             = optional(number, 3)<br/>    node_source_dest_check                                           = optional(map(bool), {})<br/>    instance_tags                                                    = optional(map(string), {})<br/>    purchase_option                                                  = optional(string, "on_demand")<br/>    instance_create_timeout                                          = optional(string, "10m")<br/>    node_instance_create_timeouts                                    = optional(map(string), {})<br/>    root_volume_encrypted                                            = optional(bool, true)<br/>    root_volume_kms_key_id                                           = optional(string, null)<br/>    cloudwatch_log_retention_days                                    = optional(number, 30)<br/>    cloudwatch_log_kms_key_id                                        = optional(string, null)<br/>    iam_path                                                         = optional(string, "/")<br/>    permissions_boundary                                             = optional(string, null)<br/>    enable_public_ipv4_on_boot                                       = optional(bool, false)<br/>    security_group_egress_profiles                                   = optional(map(string), {})<br/>    hybrid_recording_s3_actions                                      = optional(set(string), ["s3:*"])<br/>    hybrid_recording_s3_kms_key_arn                                  = optional(string, null)<br/>    hybrid_recording_s3_versioning_enabled                           = optional(bool, false)<br/>    hybrid_recording_s3_lifecycle_expiration_days                    = optional(number, null)<br/>    hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days = optional(number, null)<br/>    s3_bucket_access = optional(map(object({<br/>      bucket_name                                  = string<br/>      mode                                         = optional(string, "use_existing")<br/>      iam_profile_keys                             = set(string)<br/>      actions                                      = optional(set(string), ["s3:*"])<br/>      kms_key_arn                                  = optional(string, null)<br/>      versioning_enabled                           = optional(bool, false)<br/>      lifecycle_expiration_days                    = optional(number, null)<br/>      lifecycle_noncurrent_version_expiration_days = optional(number, null)<br/>    })), {})<br/>  })</pre> | `{}` | no |
| deployment\_mode | Zoom Node deployment mode. Use public\_cloud for direct public IPs or private\_cloud for private-only nodes. | `string` | `"public_cloud"` | no |
| domain\_name | DNS domain appended to generated Zoom Node hostnames. | `string` | n/a | yes |
| enable\_least\_privilege\_egress | Deprecated compatibility input. When true, standard workloads use workload\_specific egress unless aws.security\_group\_egress\_profiles sets an explicit profile. | `bool` | `false` | no |
| environment\_name | Optional environment prefix for node names. | `string` | `""` | no |
| explicit\_nodes | Exact Zoom Node inventory keyed by stable Terraform node identity. Use for adopting existing nodes or preserving exact hostnames and private IPs. | <pre>map(object({<br/>    node_name                            = optional(string, null)<br/>    fqdn                                 = optional(string, null)<br/>    role                                 = string<br/>    instance_type                        = string<br/>    image_channel                        = optional(string, null)<br/>    image_id                             = optional(string, null)<br/>    root_volume_gb                       = number<br/>    private_ips                          = list(string)<br/>    elastic_ips_per_node                 = optional(number, 0)<br/>    subnet_tier                          = string<br/>    subnet_index                         = optional(number, null)<br/>    purchase_option                      = optional(string, null)<br/>    instance_create_timeout              = optional(string, null)<br/>    source_dest_check                    = optional(bool, true)<br/>    metadata_http_put_response_hop_limit = optional(number, null)<br/>    security_profile                     = optional(string, null)<br/>    security_group_ids                   = optional(list(string), [])<br/>    iam_profile_key                      = optional(string, null)<br/>    iam_instance_profile_name            = optional(string, null)<br/>  }))</pre> | `{}` | no |
| generate\_node\_password | Generate a compliant 16-character Zoom Node password instead of accepting node\_password. | `bool` | `false` | no |
| hybrid\_recording\_s3\_bucket\_mode | Use create\_new to create the Hybrid Recording bucket or use\_existing to grant access to an existing bucket. | `string` | `"use_existing"` | no |
| hybrid\_recording\_s3\_bucket\_name | S3 bucket name used by Hybrid Recording. Required when Hybrid Recording is enabled. | `string` | `""` | no |
| image\_channel | Image catalog channel. Use prod for hardened production images or dev for development images that support SSH access. | `string` | `"prod"` | no |
| image\_ids | Customer-accessible Zoom Node AMI IDs by channel and AWS region. Zoom Node AMIs are private; populate the selected channel for every deployment region. | <pre>object({<br/>    prod = optional(map(string), {})<br/>    dev  = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| network\_mode | Network mode. Use create\_new to create a VPC/subnets or use\_existing to supply VPC/subnet IDs. | `string` | `"create_new"` | no |
| node\_groups | Advanced heterogeneous Zoom Node groups. Use for infrastructure roles or lab topologies that do not follow workload capacity formulas. | <pre>map(object({<br/>    count                                = number<br/>    role                                 = string<br/>    hostname_prefix                      = string<br/>    instance_type                        = string<br/>    image_channel                        = optional(string, null)<br/>    image_id                             = optional(string, null)<br/>    root_volume_gb                       = number<br/>    private_ips_per_node                 = optional(number, 1)<br/>    elastic_ips_per_node                 = optional(number, 0)<br/>    private_ip_start_offset              = number<br/>    subnet_tier                          = string<br/>    subnet_index                         = optional(number, null)<br/>    purchase_option                      = optional(string, null)<br/>    instance_create_timeout              = optional(string, null)<br/>    source_dest_check                    = optional(bool, true)<br/>    metadata_http_put_response_hop_limit = optional(number, null)<br/>    security_profile                     = string<br/>    iam_profile_key                      = string<br/>  }))</pre> | `{}` | no |
| node\_image\_ids | Optional AMI overrides keyed by stable Terraform node key, for example meetings\_hybrid-01. | `map(string)` | `{}` | no |
| node\_password | Initial Zoom Node local administrator password used in bootstrap data. Required unless generate\_node\_password is true. | `string` | `null` | no |
| registration\_code | Fresh Zoom Node registration code used in bootstrap data for newly created nodes. | `string` | n/a | yes |
| source\_cidrs | Provider-neutral source CIDRs for workload traffic. | <pre>object({<br/>    zoom_clients        = optional(list(string), ["0.0.0.0/0"])<br/>    zoom_cloud          = optional(list(string), ["0.0.0.0/0"])<br/>    remote_management_1 = optional(list(string), [])<br/>    remote_management_2 = optional(list(string), [])<br/>    internal_traffic    = optional(list(string), [])<br/>    nfs                 = optional(list(string), [])<br/>    sbc                 = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| tags | Additional tags applied to all supported AWS resources. | `map(string)` | `{}` | no |
| workloads | Provider-neutral Zoom Node workload selection and capacity inputs. | <pre>object({<br/>    meetings_hybrid = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      capacity                     = optional(number, 0)<br/>      node_count_override          = optional(number, 0)<br/>      node_private_ip_start_offset = optional(number, 10)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    hybrid_recording = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      capacity                     = optional(number, 0)<br/>      node_count_override          = optional(number, 0)<br/>      node_private_ip_start_offset = optional(number, 110)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    meeting_survivability = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      node_count                   = optional(number, 1)<br/>      node_private_ip_start_offset = optional(number, 100)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    web_application_gateway = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      capacity                     = optional(number, 0)<br/>      node_count_override          = optional(number, 0)<br/>      node_private_ip_start_offset = optional(number, 120)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    ai_services = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      node_count                   = optional(number, 1)<br/>      node_private_ip_start_offset = optional(number, 140)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    phone_local_survivability = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      capacity                     = optional(number, 0)<br/>      node_count_override          = optional(number, 0)<br/>      node_private_ip_start_offset = optional(number, 130)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| capacity\_preflight\_requests | Nonsensitive EC2 capacity requests resolved from the planned Zoom Node inventory. |
| generated\_node\_password | Generated Zoom Node administrator password when generate\_node\_password is true; otherwise null. |
| hybrid\_recording\_s3\_bucket\_name | Deprecated compatibility output. Use s3\_bucket\_names["hybrid\_recording"]. |
| iam\_instance\_profile\_names | IAM instance profile name per workload or advanced profile key. |
| instance\_ids | EC2 instance IDs by stable node key. |
| nat\_gateway\_id | NAT Gateway ID when managed NAT egress is enabled. |
| nat\_gateway\_public\_ip | NAT Gateway Elastic IP when managed NAT egress is enabled. |
| node\_fqdns | Zoom Node FQDNs by node key. |
| node\_names | Zoom Node names by node key. |
| node\_private\_ips | Private IPv4 addresses by node key. |
| node\_public\_ips | Elastic public IPv4 addresses by node key. |
| node\_purchase\_options | EC2 purchase option used by each Zoom Node. |
| node\_roles | Role assigned to each normalized node. |
| private\_subnet\_ids | Private subnet IDs used by advanced node groups. |
| public\_subnet\_ids | Public subnet IDs used by advanced node groups. |
| s3\_bucket\_names | S3 bucket names configured for advanced IAM profiles. |
| security\_group\_ids | Security group ID per enabled workload. |
| subnet\_ids | Subnets used for Zoom Node ENIs. |
| vpc\_id | VPC used for the Zoom Node deployment. |
| workload\_node\_counts | Calculated node count per enabled workload. |
<!-- END_TF_DOCS -->

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `./scripts/check-repository.sh` before submitting a change.

## License

Apache-2.0. See [LICENSE](LICENSE).
