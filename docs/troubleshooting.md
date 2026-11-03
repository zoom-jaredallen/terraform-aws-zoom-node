# Troubleshooting

## AMI is missing or rejected

Symptoms include no image for the selected channel/Region, `DescribeImages` returning no result, or architecture validation failure.

1. Confirm the provider Region and caller identity.
2. Confirm the AMI is `available`, `x86_64`, and visible to that account.
3. For an encrypted shared AMI, verify backing KMS-key access.
4. Check [AMI selection precedence](ami-management.md#selection-precedence) for a higher-priority override.

## Instance type is unavailable in an Availability Zone

The module validates whether AWS offers an instance type in the exact AZ, but an offered type can still lack physical capacity. Try another AZ, an approved equivalent instance type, On-Demand instead of Spot, or an EC2 Capacity Reservation for critical launches.

GPU types often have limited regional and zonal capacity. Do not repeatedly apply without first checking quotas and supportability.

## EC2 capacity and create timeouts

EC2 creation defaults to `10m`. Override the global timeout with `aws.instance_create_timeout`, a group/node timeout, or `aws.node_instance_create_timeouts[stable-key]`. A longer timeout does not create capacity.

The Capacity Manager preflight is optional and does not run as part of Terraform. Use it when Spot, GPU-backed, unusually large, multi-node, or single-AZ requests make current physical capacity a concern. Routine On-Demand deployments can skip it.

For an optional point-in-time score:

```bash
terraform plan -out=tfplan
capacity_check="/path/to/terraform-aws-zoom-node/scripts/check-ec2-capacity.sh"
"$capacity_check" --terraform-plan tfplan --minimum-score medium
```

Run the script from a local checkout of this module. It requires AWS CLI v2.39.1 or newer, `jq`, EC2 Capacity Manager, and AWS Support Unified Operations. See [Optional capacity preflight](prerequisites.md#optional-capacity-preflight) for the complete prerequisite list. `high`, `medium`, and `low` are supportability signals, not reservations or guarantees.

Capacity Manager can be enabled in only one Region per account. Query the Region selected for the account, even when the Terraform plan targets another Region:

```bash
aws ec2 get-capacity-manager-attributes --region us-west-2
```

If AWS returns `CapacityManager.Disabled`, an authorized administrator can enable it in the chosen control-plane Region:

```bash
aws ec2 enable-capacity-manager --region us-west-2
```

Then pass that Region to the preflight script with `--capacity-manager-region us-west-2`. Initial historical-data ingestion can take several hours, but supportability scoring is still a point-in-time advisory and does not reserve capacity.

## Elastic IP quota appears incorrect

Confirm that Terraform is using the expected AWS account and Region and that its identity can call Service Quotas and EC2 describe APIs. Expired credentials or missing permissions cause the data-source read, and therefore the plan, to fail. Compare:

```bash
aws sts get-caller-identity
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-0263D0A3 \
  --region us-west-2
```

## Cloud-init cannot find the network interface

The selected instance type lacks the correct entry in `instance-catalog.json`, or a caller override is wrong. Confirm the guest interface name for the exact AMI and instance type, then set `aws.network_interface_names_by_instance_type` or add a reviewed catalog entry. Do not assume every Nitro instance uses `ens5`.

## Node does not register

- Confirm the registration code was valid when the instance first booted.
- Confirm DNS, time, routing, security-group egress, and Zoom Cloud reachability.
- Confirm the selected AMI matches the workload and instance architecture.
- Inspect EC2 console output, cloud-init logs, and available Zoom Node agent logs.

Changing user data on an existing node does not rerun first-boot registration because bootstrap drift is intentionally ignored. Replace the node with a fresh code when re-registration is required.

## NFS connection fails

For Hybrid Recording, verify symmetric routing between the Zoom Node and NFS server, security groups/network ACLs, export client restrictions, and the NFS protocol required by the appliance. Workload-specific egress includes TCP/UDP 2049, TCP/UDP 111, and TCP/UDP 20048 only when `nfs` CIDRs are populated.

Test from an equivalent host in the same subnet when the Zoom appliance is hardened. Server-side `tcpdump`, `rpcinfo`, NFS service logs, and export logs distinguish routing failures from permission or protocol failures.

## Terraform destroy reports no objects

Terraform state determines what can be destroyed. Verify the current directory, workspace, backend configuration, and credentials. A destroy still evaluates required input variables; keep an ignored local variable file or provide syntactically valid values via `TF_VAR_*`.

## Upgrade proposes unexpected replacement

Stop before applying. Compare the change against the [replacement trigger table](terraform-upgrades.md#replacement-triggers), confirm stable node keys and AMIs, and verify that state moved into the private child modules rather than being recreated. Back up state before imports or manual state operations.
