# Documentation

This directory contains the operating and design documentation for the Terraform AWS Zoom Node module. The root [`README.md`](../README.md) is the Registry entry point and generated API reference; the guides here provide the detail needed to design, deploy, secure, and upgrade an environment.

## Start here

| Guide | Use it for |
|---|---|
| [Getting started](getting-started.md) | Planning and applying a first deployment safely |
| [Prerequisites](prerequisites.md) | Terraform, AWS, AMI, quota, network, and credential requirements |
| [Architecture](architecture.md) | Module boundaries, resource ownership, and normalized node inventory |
| [Workloads](workloads.md) | Supported Zoom workloads, default sizing, capacity, and override models |
| [Networking](networking.md) | VPC modes, subnets, IP allocation, NAT, DNS, and security profiles |
| [AMI management](ami-management.md) | Customer-owned image catalogs, channels, precedence, and replacement behavior |
| [Security](security.md) | State protection, security groups, IAM, KMS, IMDSv2, and logging |
| [Upgrade guide](terraform-upgrades.md) | Compatibility guarantees, moved blocks, imports, and replacement triggers |
| [Troubleshooting](troubleshooting.md) | Common plan, capacity, bootstrap, registration, and connectivity failures |
| [FAQ](faq.md) | Concise answers to common module and operating questions |

## Maintainers

| Guide | Use it for |
|---|---|
| [Release process](releasing.md) | Validating, tagging, and publishing immutable GitHub releases |
| [Registry readiness](registry-readiness.md) | Public Registry requirements and partner-readiness work |
| [Migration manifest](deployment-migration-manifest.md) | Tracking maintained deployment-root migrations |
| [Best-practices review](terraform-best-practices-review.md) | Current conventions assessment and improvement record |

## Examples and deployments

Copyable examples live under [`examples/`](../examples). Start with the single-node smoke test, then choose the new-VPC or existing-VPC example that matches the target environment.

Maintained, environment-specific executable roots live under [`deployments/`](../deployments). They are operational configurations, not generic examples. Never commit their state, saved plans, `.terraform` directories, `.env` files, or local variable files.
