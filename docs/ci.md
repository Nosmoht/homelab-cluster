# CI overview

## Sidero management workflows

- `sidero-management.yaml` runs manual Talos management actions.
- `sidero-config-dry-run.yaml` runs `make config-dry-run` on PRs to `main` and pushes to `main`.

### PR feedback

For pull requests, the config dry-run workflow posts a comment with the redacted
`make config-dry-run` output so you can review changes without opening logs.
