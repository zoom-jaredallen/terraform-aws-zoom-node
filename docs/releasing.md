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
6. Confirm the Terraform Registry has synchronized the new version.

Do not remove published Registry versions except to address a critical security or legal issue.
