# CI overview

## Sidero config dry-run

The `sidero-config-dry-run` workflow runs `make config-dry-run` on PRs targeting
`main` and on pushes to `main`.

For pull requests, it posts a comment with the redacted `talosctl apply-config --dry-run`
output (starting at `Dry run summary:`) so changes are visible without opening logs.
