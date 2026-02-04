# CI overview

## Sidero config dry-run

The `sidero-config-dry-run` workflow runs `make config-dry-run` on PRs targeting
`main` and on pushes to `main`, but only when files under `install/` changed.

For pull requests, it posts a comment with the redacted `talosctl apply-config --dry-run`
output (starting at `Dry run summary:`) so changes are visible without opening logs.

## Renovate updates

Renovate is configured in `renovate.json` to update the Talos version pin
(`CLUSTER_TALOS_VERSION`) in `install/versions.mk` based on stable Talos tags.

To enable it, install the Renovate GitHub App for this repository (or run a
self-hosted Renovate instance) and allow it to open pull requests.
