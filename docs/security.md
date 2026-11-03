# Security

## Sensitive data and state

Terraform renders the Zoom registration code and node password into EC2 user data. These values are stored in state and saved plans even though the input variables are marked sensitive.

- Use an encrypted, access-controlled remote backend with locking and recovery.
- Keep state, plans, `.env`, and local variable files out of Git.
- Inject secrets through a secret-aware CI system or `TF_VAR_*` environment variables.
- Remove expired plan files after apply.
- Do not include state or plan files in support cases or public issues.

Optional generated passwords are also stored in state. Retrieve one with `terraform output -raw generated_node_password` and place it in the approved secret manager.

## Security groups

Security groups and rules are workload-specific. Every standard workload allows management TCP/8443 only from `remote_management_1` and `remote_management_2`.

| Workload | Additional ingress |
|---|---|
| Meetings Hybrid | Client TCP/80, TCP/443, UDP/8801-8803 |
| Hybrid Recording | Client TCP/443 |
| Meeting Survivability | Client TCP/443; management TCP/8080; internal TCP/3306 |
| Web Application Gateway | Client TCP/443, TCP/8801-8802, UDP/8801-8810 |
| AI Services | None beyond management |
| Phone Local Survivability | Client TCP/5091 and UDP/20000-64000; internal TCP/9443; SBC TCP/5061 and UDP/20000-64000 |

The module's rules reflect its current tested contract. Validate them against the current Zoom Support firewall documentation and customer policy before production use.

## Egress profiles

Egress defaults to `allow_all` for backward compatibility. Set `aws.security_group_egress_profiles` by workload or advanced profile key to one of:

| Profile | Behavior |
|---|---|
| `allow_all` | All IPv4 outbound traffic |
| `workload_specific` | Only the workload rules generated from `zoom_cloud`, `nfs`, `sbc`, and internal CIDRs |
| `deny_all` | No module-managed outbound rule |

Adopt `workload_specific` only after populating precise destination CIDRs and testing DNS, time, registration, software, storage, and Zoom Cloud dependencies. `enable_least_privilege_egress` remains deprecated compatibility behavior.

## Instance metadata and routing

EC2 instances require IMDSv2. The HTTP PUT response hop limit defaults to `3` to support containerized workloads. Reduce it only when the appliance networking model permits.

Source/destination checking defaults to `true`. Disable it per stable node key only for nodes that intentionally route traffic, such as a Kubernetes control plane using kube-vip.

## IAM and S3

S3 access policies are bucket-scoped but default to `s3:*` for the configured bucket and objects. Supply a smaller `actions` set when the application contract is known. IAM profile keys let multiple nodes share one module-managed role and profile.

For `mode = "create_new"`, the module can manage versioning and lifecycle expiration. For `use_existing`, bucket versioning, lifecycle, encryption, public access, and policy remain the external owner's responsibility.

## Encryption and logging

- Root EBS volumes are encrypted by default.
- Optional external KMS keys can protect EBS, CloudWatch Logs, and S3 objects.
- The caller owns all KMS key policies and rotation.
- CloudWatch log retention defaults to 30 days and is configurable.
- EC2-only custom tags belong in `aws.instance_tags`; general `tags` apply to supported module resources.

## Supply chain

Pin production callers to immutable semantic-version tags. Review `CHANGELOG.md`, verify the GitHub release, run a saved plan, and follow the [upgrade guide](terraform-upgrades.md). Never consume a mutable branch in a production root.

Report suspected vulnerabilities through GitHub private vulnerability reporting as described in [`SECURITY.md`](../SECURITY.md).
