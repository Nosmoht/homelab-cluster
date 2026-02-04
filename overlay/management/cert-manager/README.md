# Prerequisite

Create the DNS solver secret in namespace `cert-manager` before syncing this overlay:

```bash
kubectl --context admin@sidero -n cert-manager create secret generic google-cloud-dns \
  --from-file=service-account-key.json=/path/to/service-account-key.json
```

The service account should only have the minimum Google Cloud DNS permissions
required for ACME DNS-01 challenges.
