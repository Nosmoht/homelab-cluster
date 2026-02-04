# CI overview

## Sidero config dry-run

The `sidero-config-dry-run` workflow runs `make config-dry-run` on PRs targeting
`main` and on pushes to `main`, but only when files under `install/` changed.

For pull requests, it posts a comment with the redacted `talosctl apply-config --dry-run`
output (starting at `Dry run summary:`) so changes are visible without opening logs.

## cert-manager secret health

The `cert-manager-secret-health` workflow validates cert-manager secret hygiene
for management manifests on PRs to `main` and pushes to `main` (path-filtered):

- the Cloud DNS key file is not tracked in Git
- `.gitignore` protects `service-account-key.json`
- no `secretGenerator` is used for cert-manager credentials
- issuers reference `google-cloud-dns` with `service-account-key.json`
- docs include secret creation and health-check commands

## Renovate updates

Renovate is configured in `renovate.json` to update the Talos version pin
(`CLUSTER_TALOS_VERSION`) in `install/versions.mk` based on stable Talos tags.

To enable it, install the Renovate GitHub App for this repository (or run a
self-hosted Renovate instance) and allow it to open pull requests.
