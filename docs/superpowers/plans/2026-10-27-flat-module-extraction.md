# Flat Implementation Module Extraction Plan

Spec: `docs/superpowers/specs/2026-10-27-flat-module-extraction-design.md`

1. Add a failing static contract for module directories and complete state moves.
2. Extract network resources and delegate root network outputs.
3. Extract storage and IAM resources and delegate root storage outputs.
4. Extract security and compute resources into the node module.
5. Update native tests to assert through private module contract outputs.
6. Document the architecture and migration guarantee.
7. Run the full repository verification suite and review the complete diff.

Ruling: generated password and cloud-init rendering remain in the facade because moving password generation into the node module would create a circular input dependency. This preserves its state address and keeps secrets out of broad child-module outputs.

