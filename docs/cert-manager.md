# cert-manager on management cluster

This cluster runs cert-manager for management-plane TLS (for example `argocd.homelab.ntbc.io`).

## GitOps source

- Argo CD app: `cert-manager`
- App path: `overlay/management/cert-manager`
- Base manifests: `base/cert-manager/v1.19.3`

## Security and production defaults

- cert-manager version is pinned to a stable upstream release.
- ACME DNS-01 solver is restricted to `homelab.ntbc.io` via `dnsZones` selector.
- A separate staging issuer (`homelab-staging`) is available for non-production testing.
- Cloud DNS credentials are **not** stored in Git.

## Secret prerequisite

Create the DNS solver secret before first sync:

```bash
kubectl --context admin@sidero -n cert-manager create secret generic google-cloud-dns \
  --from-file=service-account-key.json=/path/to/service-account-key.json
```

## Secret health-check

Verify that the required secret exists and contains the expected key:

```bash
kubectl --context admin@sidero -n cert-manager get secret google-cloud-dns
kubectl --context admin@sidero -n cert-manager get secret google-cloud-dns \
  -o jsonpath='{.data.service-account-key\\.json}' | wc -c
```

The second command must return a value greater than `0`.

CI enforces this baseline via workflow `cert-manager-secret-health`.

## Verification

```bash
kubectl --context admin@sidero -n argocd get application cert-manager
kubectl --context admin@sidero -n cert-manager get deploy
kubectl --context admin@sidero get clusterissuer homelab homelab-staging
kubectl --context admin@sidero get certificates.cert-manager.io -A
```
