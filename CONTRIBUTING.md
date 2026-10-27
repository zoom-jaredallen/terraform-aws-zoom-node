# Contributing

Contributions are welcome through GitHub issues and pull requests.

## Development

Install Terraform, terraform-docs, TFLint with the AWS ruleset, and Trivy. Then run:

```bash
./scripts/check-repository.sh
```

Keep changes backward compatible within the current major version. Preserve stable resource addresses and retain every `moved` block added to the module. Update `CHANGELOG.md`, tests, examples, and generated README documentation with public-interface changes.

Do not commit registration codes, passwords, AWS credentials, Terraform state, saved plans, local variable files, or `.terraform/` directories.

By submitting a contribution, you agree that it is licensed under the Apache License 2.0.
