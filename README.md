# Terraform AWS Zoom Node

An AWS-native Terraform module for deploying Zoom Node workloads.

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.7-844FBA.svg)](https://www.terraform.io/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Usage

```hcl
module "zoom_node" {
  source  = "zoom-jaredallen/zoom-node/aws"
  version = "~> 0.1"

  environment_name       = "demo"
  domain_name            = "lab.example.com"
  deployment_mode        = "public_cloud"
  network_mode           = "create_new"
  registration_code      = var.registration_code
  generate_node_password = true

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
- Plan-time validation for Zoom bootstrap values, management CIDRs, selected workload capacity, Elastic IP mapping, and regional Elastic IP quota
- Advanced heterogeneous node groups with per-group images, sizing, subnet tiers, Spot selection, IMDS settings, security profiles, and shared IAM profiles
- Public and private subnet tiers with optional NAT Gateway egress
- Bucket-scoped S3 access shared by one or more advanced IAM profiles

The public interface uses portable names such as `deployment_mode`, `network_mode`, `workloads`, and `source_cidrs`. AWS-specific values live inside the `aws` object so Azure, GCP, OCI, and Crossplane implementations can reuse the higher-level deployment contract later.

Use `node_groups` for infrastructure roles or heterogeneous lab topologies that do not belong in the Zoom workload capacity catalog. Groups normalize into the same EC2, ENI, Cloud Init, EIP, and output path as `workloads`. Their `subnet_tier` selects a public or private subnet, and groups with the same `iam_profile_key` share one IAM role and instance profile.

An advanced group can set `subnet_index` to select a specific zero-based subnet and Availability Zone within its tier. Omitting it preserves the existing single-AZ or round-robin placement behavior. When a higher index is selected with `network_mode = "create_new"`, the module expands only that subnet tier, so existing groups retain their current subnet indexes and are not redistributed.

Set `aws.create_nat_gateway = true` when private groups need outbound access. The module creates one NAT Gateway in the first public subnet and routes private-subnet IPv4 traffic through it. Use `aws.s3_bucket_access` to create or reference named buckets and grant bucket-scoped actions to selected IAM profile keys.

Set `aws.security_group_egress_profiles` by workload or advanced security-profile key to choose `allow_all`, `workload_specific`, or `deny_all`. Existing configurations keep unrestricted egress by default. `enable_least_privilege_egress` is deprecated but remains supported for compatibility.

Customer-managed KMS key inputs reference externally managed keys. The caller is responsible for key policies. Versioning and lifecycle settings apply only to buckets created by this module. See [`docs/terraform-upgrades.md`](docs/terraform-upgrades.md) before upgrading an existing deployment, especially for the one-time inline-to-standalone security-rule migration.

## Example

```hcl
module "zoom_node" {
  source  = "zoom-jaredallen/zoom-node/aws"
  version = "~> 0.1"

  environment_name  = "demo"
  domain_name       = "lab.example.com"
  deployment_mode   = "public_cloud"
  network_mode      = "create_new"
  registration_code = var.registration_code
  generate_node_password = true

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

Terraform stores rendered user data in state. Treat the state backend as sensitive because `registration_code` and `node_password` are rendered into cloud-init.

Set `generate_node_password = true` to let the module create a compliant 16-character password. In this mode, omit `node_password` and retrieve the result with `terraform output -raw generated_node_password`. To supply a password instead, leave generation disabled and pass `node_password` through a sensitive variable or `TF_VAR_node_password`. Terraform rejects configurations that select both methods or neither method.

Start with [`examples/aws-smoke-single-node`](examples/aws-smoke-single-node) when testing in a real AWS account. It deploys one Meeting Survivability node and exercises the same network, ENI, security group, Elastic IP, and user-data paths with a smaller blast radius.

The module reads the EC2 regional Elastic IP quota and existing EIP allocations during planning. Public cloud deployments fail early when the selected workloads need more Elastic IPs than the account can allocate in the target region.

Default AWS AMIs live in `image-catalog.json`, grouped by `prod` and `dev` channel and then AWS region. `image_channel` defaults to `prod`. Select `dev` for an SSH-enabled development image; a missing image in the selected channel and region fails during planning rather than falling back to production. The repository does not ship placeholder AMI IDs, so populate the `dev` catalog with published regional images before selecting it.

AMI selection uses this precedence, from highest to lowest:

1. `node_image_ids` entry keyed by the stable Terraform node key, such as `meetings_hybrid-01`.
2. Workload-specific `image_id`.
3. Global `aws.image_id`.
4. Regional `aws.image_ids` entry.
5. The selected `image_catalog.json` channel and AWS region.

For example, this selects development images generally while replacing one generated node with a specific AMI:

```hcl
image_channel = "dev"

node_image_ids = {
  meetings_hybrid-01 = "ami-0123456789abcdef0"
}
```

Workload sizing, capacity, storage, IP allocation, and provider instance recommendations live in `workload-catalog.json`. The module derives its AWS defaults from that catalog while keeping workload-specific Terraform overrides available for exceptional deployments.

AI Services defaults to `g6.12xlarge` with a 500 GB root volume, one private IP, and no Elastic IPs. It also supports `g7e.2xlarge` as an override. The module validates selected EC2 instance types against the current AWS region during planning, because GPU-backed `g6` and `g7e` families are not available everywhere.

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
| [aws_cloudwatch_log_group.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.hybrid_recording_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.node_group_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_instance.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_network_interface.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_interface) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.hybrid_recording](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.hybrid_recording](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.hybrid_recording](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.hybrid_recording](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.hybrid_recording](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_security_group_egress_rule.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.zoom_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_password.node](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [terraform_data.validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_ec2_instance_type_offerings.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_type_offerings) | data source |
| [aws_eips.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eips) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_servicequotas_service_quota.ec2_elastic_ips](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/servicequotas_service_quota) | data source |
| [aws_subnet.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| availability\_zone\_config | Node placement model. | `string` | `"single_az"` | no |
| aws | AWS-specific settings kept behind the portable Zoom Node interface. | <pre>object({<br/>    image_id                                                         = optional(string, "")<br/>    image_ids                                                        = optional(map(string), {})<br/>    key_name                                                         = optional(string, null)<br/>    vpc_cidr                                                         = optional(string, "10.0.0.0/16")<br/>    subnet_cidrs                                                     = optional(list(string), [])<br/>    public_subnet_cidrs                                              = optional(list(string), [])<br/>    private_subnet_cidrs                                             = optional(list(string), [])<br/>    create_nat_gateway                                               = optional(bool, false)<br/>    availability_zones                                               = optional(list(string), [])<br/>    existing_vpc_id                                                  = optional(string, "")<br/>    existing_subnet_ids                                              = optional(list(string), [])<br/>    subnet_newbits                                                   = optional(number, 8)<br/>    dns_servers                                                      = optional(list(string), [])<br/>    network_interface_name                                           = optional(string, "")<br/>    network_interface_names_by_instance_type                         = optional(map(string), {})<br/>    network_interface_names_by_instance_family                       = optional(map(string), {})<br/>    metadata_http_put_response_hop_limit                             = optional(number, 3)<br/>    node_source_dest_check                                           = optional(map(bool), {})<br/>    instance_tags                                                    = optional(map(string), {})<br/>    purchase_option                                                  = optional(string, "on_demand")<br/>    root_volume_encrypted                                            = optional(bool, true)<br/>    root_volume_kms_key_id                                           = optional(string, null)<br/>    cloudwatch_log_retention_days                                    = optional(number, 30)<br/>    cloudwatch_log_kms_key_id                                        = optional(string, null)<br/>    iam_path                                                         = optional(string, "/")<br/>    permissions_boundary                                             = optional(string, null)<br/>    enable_public_ipv4_on_boot                                       = optional(bool, false)<br/>    security_group_egress_profiles                                   = optional(map(string), {})<br/>    hybrid_recording_s3_actions                                      = optional(set(string), ["s3:*"])<br/>    hybrid_recording_s3_kms_key_arn                                  = optional(string, null)<br/>    hybrid_recording_s3_versioning_enabled                           = optional(bool, false)<br/>    hybrid_recording_s3_lifecycle_expiration_days                    = optional(number, null)<br/>    hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days = optional(number, null)<br/>    s3_bucket_access = optional(map(object({<br/>      bucket_name                                  = string<br/>      mode                                         = optional(string, "use_existing")<br/>      iam_profile_keys                             = set(string)<br/>      actions                                      = optional(set(string), ["s3:*"])<br/>      kms_key_arn                                  = optional(string, null)<br/>      versioning_enabled                           = optional(bool, false)<br/>      lifecycle_expiration_days                    = optional(number, null)<br/>      lifecycle_noncurrent_version_expiration_days = optional(number, null)<br/>    })), {})<br/>  })</pre> | `{}` | no |
| deployment\_mode | Zoom Node deployment mode. Use public\_cloud for direct public IPs or private\_cloud for private-only nodes. | `string` | `"public_cloud"` | no |
| domain\_name | DNS domain appended to generated Zoom Node hostnames. | `string` | n/a | yes |
| enable\_least\_privilege\_egress | Deprecated compatibility input. When true, standard workloads use workload\_specific egress unless aws.security\_group\_egress\_profiles sets an explicit profile. | `bool` | `false` | no |
| environment\_name | Optional environment prefix for node names. | `string` | `""` | no |
| generate\_node\_password | Generate a compliant 16-character Zoom Node password instead of accepting node\_password. | `bool` | `false` | no |
| hybrid\_recording\_s3\_bucket\_mode | Use create\_new to create the Hybrid Recording bucket or use\_existing to grant access to an existing bucket. | `string` | `"use_existing"` | no |
| hybrid\_recording\_s3\_bucket\_name | S3 bucket name used by Hybrid Recording. Required when Hybrid Recording is enabled. | `string` | `""` | no |
| image\_channel | Image catalog channel. Use prod for hardened production images or dev for development images that support SSH access. | `string` | `"prod"` | no |
| network\_mode | Network mode. Use create\_new to create a VPC/subnets or use\_existing to supply VPC/subnet IDs. | `string` | `"create_new"` | no |
| node\_groups | Advanced heterogeneous Zoom Node groups. Use for infrastructure roles or lab topologies that do not follow workload capacity formulas. | <pre>map(object({<br/>    count                                = number<br/>    role                                 = string<br/>    hostname_prefix                      = string<br/>    instance_type                        = string<br/>    image_channel                        = optional(string, null)<br/>    image_id                             = optional(string, null)<br/>    root_volume_gb                       = number<br/>    private_ips_per_node                 = optional(number, 1)<br/>    elastic_ips_per_node                 = optional(number, 0)<br/>    private_ip_start_offset              = number<br/>    subnet_tier                          = string<br/>    subnet_index                         = optional(number, null)<br/>    purchase_option                      = optional(string, null)<br/>    source_dest_check                    = optional(bool, true)<br/>    metadata_http_put_response_hop_limit = optional(number, null)<br/>    security_profile                     = string<br/>    iam_profile_key                      = string<br/>  }))</pre> | `{}` | no |
| node\_image\_ids | Optional AMI overrides keyed by stable Terraform node key, for example meetings\_hybrid-01. | `map(string)` | `{}` | no |
| node\_password | Initial Zoom Node local administrator password used in bootstrap data. Required unless generate\_node\_password is true. | `string` | `null` | no |
| registration\_code | Fresh Zoom Node registration code used in bootstrap data for newly created nodes. | `string` | n/a | yes |
| source\_cidrs | Provider-neutral source CIDRs for workload traffic. | <pre>object({<br/>    zoom_clients        = optional(list(string), ["0.0.0.0/0"])<br/>    zoom_cloud          = optional(list(string), ["0.0.0.0/0"])<br/>    remote_management_1 = optional(list(string), [])<br/>    remote_management_2 = optional(list(string), [])<br/>    internal_traffic    = optional(list(string), [])<br/>    nfs                 = optional(list(string), [])<br/>    sbc                 = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| tags | Additional tags applied to all supported AWS resources. | `map(string)` | `{}` | no |
| workloads | Provider-neutral Zoom Node workload selection and capacity inputs. | <pre>object({<br/>    meetings_hybrid = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      capacity                     = optional(number, 0)<br/>      node_count_override          = optional(number, 0)<br/>      node_private_ip_start_offset = optional(number, 10)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    hybrid_recording = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      capacity                     = optional(number, 0)<br/>      node_count_override          = optional(number, 0)<br/>      node_private_ip_start_offset = optional(number, 110)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    meeting_survivability = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      node_count                   = optional(number, 1)<br/>      node_private_ip_start_offset = optional(number, 100)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    web_application_gateway = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      capacity                     = optional(number, 0)<br/>      node_count_override          = optional(number, 0)<br/>      node_private_ip_start_offset = optional(number, 120)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    ai_services = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      node_count                   = optional(number, 1)<br/>      node_private_ip_start_offset = optional(number, 140)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>    phone_local_survivability = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      capacity                     = optional(number, 0)<br/>      node_count_override          = optional(number, 0)<br/>      node_private_ip_start_offset = optional(number, 130)<br/>      instance_type                = optional(string, null)<br/>      image_id                     = optional(string, null)<br/>      root_volume_gb               = optional(number, null)<br/>      private_ips_per_eni          = optional(number, null)<br/>      elastic_ips_per_node         = optional(number, null)<br/>    }), {})<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| generated\_node\_password | Generated Zoom Node administrator password when generate\_node\_password is true; otherwise null. |
| hybrid\_recording\_s3\_bucket\_name | Hybrid Recording S3 bucket name, when configured. |
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
