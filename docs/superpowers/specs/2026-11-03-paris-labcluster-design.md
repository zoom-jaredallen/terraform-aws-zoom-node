# Paris Lab Cluster Design

## Intent

Create an independent Paris deployment based on `us-west-2-labcluster` so the same eight-node Zoom Node lab can use currently stronger `g6.12xlarge` capacity without sharing Terraform state or regional resources with US West.

## Approved approach

Use a separate `deployments/eu-west-3-paris-labcluster` root pinned to immutable module release `v0.4.1`. Copy the account-owned US West production and development AMIs into `eu-west-3`, encrypt the destination snapshots with `alias/aws/ebs`, wait for both images to become available, and add their IDs to the shared deployment AMI catalog.

The alternative considered was generalizing one stateful deployment root for multiple regions. It was rejected because independent roots make regional state, AMIs, networking, credentials, and lifecycle operations safer and easier to reason about.

## Topology

- Region and Availability Zone: `eu-west-3` and `eu-west-3b`.
- VPC and subnets: `10.30.0.0/16`, public `10.30.0.0/24`, private `10.30.1.0/24` and `10.30.2.0/24`.
- Nodes: one Meetings Hybrid, one Kubernetes master, five Kubernetes workers, and one `g6.12xlarge` AI Services node.
- Purchasing: On-Demand for every node group.
- EIPs, disks, IMDS, source/destination checks, security profiles, IAM profiles, tags, management CIDRs, and domain inherit the US West design.
- Bucket: `zoomnode-paris-labcluster-s3`.
- All nodes initially use `eu-west-3b` to avoid cross-AZ NAT processing. The AI Services group retains its dedicated private subnet.

## Safety constraints

- Do not copy Terraform state, saved plans, `.terraform`, lock metadata, credentials, generated passwords, or registration codes from US West.
- Do not create EC2 instances in this change.
- Keep the committed registration-code placeholder intentionally invalid so accidental plans and applies fail closed. Automated validation may supply `AAAAAAAAAAAAAAAA` explicitly on the command line and must never apply that plan.
- Confirm both copied AMIs are available, encrypted, account-owned, and `x86_64` before recording them.
- A future apply requires a fresh Zoom registration code and explicit approval.
