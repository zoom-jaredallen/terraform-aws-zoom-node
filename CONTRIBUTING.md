# Contributing

Contributions are welcome through GitHub issues and pull requests.

## Development

Install Terraform, terraform-docs `v0.24.0`, TFLint with the AWS ruleset, and Trivy. Then run:

```bash
./scripts/check-repository.sh
```

Keep changes backward compatible within the current major version. Preserve stable resource addresses and retain every `moved` block added to the module. Update `CHANGELOG.md`, tests, examples, and generated README documentation with public-interface changes.

When provider selections change, regenerate every example lock file for the supported development and CI platforms:

```bash
terraform providers lock -platform=darwin_arm64 -platform=linux_amd64 -platform=linux_arm64
```

Do not commit registration codes, passwords, AWS credentials, Terraform state, saved plans, local variable files, or `.terraform/` directories.

By submitting a contribution, you agree that it is licensed under the Apache License 2.0.
