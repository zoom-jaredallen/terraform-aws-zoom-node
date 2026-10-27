# Releasing

1. Update `CHANGELOG.md` with the release version and date.
2. Run `./scripts/check-repository.sh` from a clean checkout.
3. Confirm the release contains no credentials, state, plans, local variable files, or Terraform working directories.
4. Create and push an annotated semantic-version tag:

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin main vX.Y.Z
```

5. Create matching GitHub release notes.
6. Confirm consumers can resolve the immutable GitHub tag.
7. If Terraform Registry publication is enabled, confirm the Registry has synchronized the new version.

GitHub releases are currently the module's distribution mechanism. Terraform Registry publication is optional and must be explicitly enabled before adding Registry source examples to the documentation.

Do not remove published GitHub releases or Registry versions except to address a critical security or legal issue.
