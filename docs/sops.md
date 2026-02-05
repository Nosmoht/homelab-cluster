# SOPS GitOps Secrets for Argo CD

This runbook describes how to store SSO secrets encrypted in git and let Argo CD
decrypt them at render time.

## Why this is useful

- Secrets are committed encrypted (`*.sops.yaml`) instead of plaintext.
- Argo CD applies secrets automatically during sync.
- Manual bootstrap is reduced to one trust-anchor step (install age private key
  in the `argocd` namespace).

## Prerequisites

- `age-keygen`
- `sops`
- `kubectl`
- access to the management cluster context (`admin@sidero` by default)

## 1) Bootstrap SOPS key material (one-time)

```bash
make -C install bootstrap-sops
```

What this does:

- creates local age private key at `install/sops-age.key` (if missing)
- updates `.sops.yaml` recipient placeholder
- creates/updates Kubernetes Secret `argocd/sops-age`

## 2) Generate encrypted SSO secrets

Export your real OAuth values first:

```bash
export GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>"
export GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>"
```

Generate encrypted manifests:

```bash
./scripts/generate-sso-sops-secrets.sh
```

This writes:

- `overlay/management/dex/dex-oidc-secrets.sops.yaml`
- `overlay/management/argocd/argocd-secret-sso.sops.yaml`
- `overlay/management/argo-workflows/argo-workflows-sso-oidc.sops.yaml`

## 3) Enable KSOPS generators

Use the helper script:

```bash
./scripts/enable-sso-sops-generators.sh
```

Generator manifests are already provided in the repo:

- `overlay/management/dex/dex-oidc-secrets-generator.yaml`
- `overlay/management/argocd/argocd-secret-sso-generator.yaml`
- `overlay/management/argo-workflows/argo-workflows-sso-oidc-generator.yaml`

## 4) Commit and sync

Commit `.sops.yaml`, generator-enabled kustomizations, and the generated
`*.sops.yaml` files.

Then sync Argo CD.

## Validation

```bash
kubectl --context admin@sidero -n argocd get secret sops-age
kubectl --context admin@sidero -n argocd get secret argocd-secret
kubectl --context admin@sidero -n dex get secret dex-oidc-secrets
kubectl --context admin@sidero -n argo get secret argo-workflows-sso-oidc
```

If generators are enabled, local builds must run with plugin flags and `ksops`
available in `PATH`:

```bash
kustomize build --enable-alpha-plugins --enable-exec overlay/management/argocd
kustomize build --enable-alpha-plugins --enable-exec overlay/management/argo-workflows
kustomize build --enable-alpha-plugins --enable-exec overlay/management/dex
```

## Important notes

- This reduces bootstrap effort, but does not remove it entirely.
- Keep `install/sops-age.key` safe and backed up.
- Never commit unencrypted secret files.
