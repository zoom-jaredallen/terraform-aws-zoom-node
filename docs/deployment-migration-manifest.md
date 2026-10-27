# Deployment Migration Manifest

Captured on 2026-10-27 using AWS account `626657815993`. Raw state and AWS responses are stored only in each deployment's git-ignored `.migration/` directory.

| Deployment | Region | State status | AWS status | Migration disposition |
|---|---|---|---|---|
| `us-west-2-labcluster` | `us-west-2` | Current state serial 252, lineage `5e6663dd-fbf2-3af3-19fd-16675e6055e8`, zero resources | No matching active/stopped lab-cluster instances | Retired/destroyed; refactor configuration only and do not apply without explicit approval to recreate |
| `tokyo-ai-services-explicit-node` | `ap-northeast-1` | Serial 50, lineage `92f0d886-7744-ae08-7314-4245fc89134d`, live state | Two instances and ENIs match state | Live migration using declarative moves |
| `govtech-ap-southeast-1-explicit-nodes` | `ap-southeast-1` | Serial 161, lineage `b17b1f94-70f5-c91d-d41e-689acc9b49c0`, live state | Eight instances and ENIs match state | Live migration using declarative moves |
| `sydney-public-four-node-new-vpc` | `ap-southeast-2` | Current and backup state serial 38, lineage `bcc33383-c7a7-e069-9176-a891ff124530`, zero resources | Four stopped instances and their VPC resources still exist | Orphaned infrastructure; import into module addresses before any apply |

## Tokyo Baseline

| Node | Instance | ENI | Private IP | Type | AMI | Disk |
|---|---|---|---|---|---|---:|
| `jp01worker1-ap-northeast-1a` | `i-00a49f13565822610` | `eni-065f85abf6d31b1f7` | `10.2.101.241` | `g6.12xlarge` | `ami-0f31cf9510e341030` | 500 GB |
| `jp01worker2-ap-northeast-1a` | `i-0c60e8a31ffffe302` | `eni-0a1b36feb73a60a5e` | `10.2.101.242` | `g6.2xlarge` | `ami-0f31cf9510e341030` | 500 GB |

Both ENIs use security group `sg-0b48e7ed7e0a5855e`. Neither instance has an IAM instance profile or EIP.

## GovTech Baseline

| Node class | Nodes | Private IPs | Type | AMI | Disk |
|---|---:|---|---|---|---:|
| Control plane | 3 | `10.0.101.251-253` | `t3.xlarge` | `ami-0d60ba6c4adea94cf` | 500 GB |
| Worker | 5 | `10.0.101.241-245` | `m7i.2xlarge` | `ami-0d60ba6c4adea94cf` | 500 GB |

All eight ENIs use security group `sg-0d9070fbb749a5ff4`. All instances use external IAM instance profile `ZoomNodeS3Access`. Exact instance and ENI IDs are retained in the ignored baseline files for post-migration comparison.

## Sydney Discovery Baseline

| Node | Instance | ENI | EIP allocation | Private IP | Public IP |
|---|---|---|---|---|---|
| `syd01node1-ap-southeast-2a` | `i-0558701eab94b0d30` | `eni-05160d655b886e654` | `eipalloc-0ec16e87303bc4394` | `10.20.101.10` | `13.237.180.96` |
| `syd01node2-ap-southeast-2a` | `i-0fc581b0191927654` | `eni-0e0e8e5c779ec5a37` | `eipalloc-0d7af3e0a19890818` | `10.20.101.20` | `3.105.218.28` |
| `syd01node3-ap-southeast-2a` | `i-0268da7278ea573fb` | `eni-079c5bf7553e18652` | `eipalloc-057f45935bc4e1965` | `10.20.101.30` | `32.236.120.221` |
| `syd01node4-ap-southeast-2a` | `i-0a970d6f8f90f86c4` | `eni-09b2bc4e38b64fdc6` | `eipalloc-08118a9a88354431c` | `10.20.101.40` | `13.238.70.164` |

Shared infrastructure:

- VPC: `vpc-081b71423786fc0d2`
- Subnet: `subnet-00800f4d06bd5d5bb` (`10.20.101.0/24`, `ap-southeast-2a`)
- Internet gateway: `igw-0f1a9645d8451c4ed`
- Public route table: `rtb-02b9833b1888f8a25`
- Security group: `sg-03bafcdd8e11c76f9`

Because no Terraform state owns these resources, Sydney requires declarative import blocks or reviewed `terraform import` operations. It must not use `moved` blocks from nonexistent source addresses.
