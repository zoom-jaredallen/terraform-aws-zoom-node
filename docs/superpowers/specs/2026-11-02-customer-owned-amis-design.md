# Customer-Owned AMIs Design

## Intent

Make private Zoom Node AMIs an explicit customer-owned deployment input. The public module must not imply that embedded AMI IDs are launchable from arbitrary AWS accounts.

## Design

- Add a top-level `image_ids` object with `prod` and `dev` regional maps. This is the preferred reusable input for customer environments.
- Preserve `aws.image_id`, `aws.image_ids`, workload `image_id`, group `image_id`, explicit-node `image_id`, and `node_image_ids` for compatibility and exceptional overrides.
- Resolve images in this order: stable node override, workload/group/explicit-node override, customer channel/region map, global AWS override, legacy regional AWS map, bundled catalog.
- Empty the bundled AWS image catalog. It remains as a schema-compatible final fallback so a future public distribution mechanism can populate it without another interface change.
- Query each distinct selected AMI during planning using its exact image ID, then require the returned image to be `available` and `x86_64`. An image that is absent, inaccessible, unavailable, or incompatible must fail before resource creation.
- Do not add SSM Parameter Store support in this change. Customer-managed SSM lookup remains a possible later enhancement and is not needed for a clear initial workflow.

## Documentation

Document that AMI IDs are regional and may be account-specific, explain the sharing/copying prerequisite, provide copyable single-region and channel-aware examples, and add a focused customer AMI catalog example.

## Compatibility

Existing immutable module releases and deployments pinned to them are unchanged. Existing override inputs continue to work in the new release. Deployments that relied only on the formerly bundled private IDs must supply an accessible AMI when upgrading.

