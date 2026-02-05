# Dex SSO for Argo CD and Argo Workflows

This repo runs a standalone Dex in the management cluster and uses it as the
OIDC provider for:

- Argo CD (`https://$ARGOCD_HOST`)
- Argo Workflows (`https://$ARGO_WORKFLOWS_HOST`)

Dex endpoint:

- `https://$DEX_HOST`

## Mode selection

- **Recommended (GitOps + encrypted secrets):** use SOPS flow in `docs/sops.md`
- **Manual fallback:** continue with this document's secret bootstrap commands

## 1) Set endpoint variables

Use environment variables to define all DNS names consistently:

```bash
export SSO_BASE_DOMAIN="example.com"
export DEX_HOST="dex.${SSO_BASE_DOMAIN}"
export ARGOCD_HOST="argocd.${SSO_BASE_DOMAIN}"
export ARGO_WORKFLOWS_HOST="argoworkflows.${SSO_BASE_DOMAIN}"
```

## 2) Google OAuth prerequisites

In Google Cloud Console, create an OAuth client of type **Web application**.

Required redirect URI:

- `https://${DEX_HOST}/callback`

## 3) Configure SSO endpoints in manifests

Update all SSO-related hostnames in manifests with one command:

```bash
./scripts/configure-sso-endpoints.sh
```

The script uses:

- `SSO_BASE_DOMAIN` (default: `example.com`)
- `DEX_HOST` (default: `dex.${SSO_BASE_DOMAIN}`)
- `ARGOCD_HOST` (default: `argocd.${SSO_BASE_DOMAIN}`)
- `ARGO_WORKFLOWS_HOST` (default: `argoworkflows.${SSO_BASE_DOMAIN}`)

Review and commit the changed files before syncing with Argo CD.

## 4) Configure the admin identity

Before applying SSO manifests, set your own admin identity in both files:

- `overlay/management/argocd/argocd-rbac-cm-sso-patch.yaml`
- `overlay/management/argo-workflows/sso-rbac.yaml`

Replace `sso-admin@example.com` with your own OIDC email claim, for example:

```bash
export SSO_ADMIN_EMAIL="you@example.com"
```

Then update both files (or edit them manually):

```bash
SSO_ADMIN_EMAIL_ESCAPED="$(printf '%s\n' "${SSO_ADMIN_EMAIL}" | sed 's/[&/]/\\&/g')"

for f in \
  overlay/management/argocd/argocd-rbac-cm-sso-patch.yaml \
  overlay/management/argo-workflows/sso-rbac.yaml; do
  sed "s/sso-admin@example.com/${SSO_ADMIN_EMAIL_ESCAPED}/g" "${f}" > "${f}.tmp"
  mv "${f}.tmp" "${f}"
done
```

## 5) Scratch setup (minimal manual steps)

For a fresh cluster, run this once before creating SSO secrets.
`scripts/bootstrap-sso.sh` performs exactly these bootstrap steps automatically.
The script is idempotent and can be re-run.

```bash
export K8S_CONTEXT="admin@sidero"

# Ensure required namespaces exist.
for ns in argocd argo dex; do
  kubectl --context "${K8S_CONTEXT}" create namespace "${ns}" --dry-run=client -o yaml \
    | kubectl --context "${K8S_CONTEXT}" apply -f -
done

# Bootstrap app-of-apps (idempotent).
kubectl --context "${K8S_CONTEXT}" apply -f apps/management-root.yaml

# Optional but useful: trigger a hard refresh so namespaces/apps reconcile immediately.
kubectl --context "${K8S_CONTEXT}" -n argocd annotate application management-apps \
  argocd.argoproj.io/refresh=hard --overwrite
```

Why this is needed:

- `dex-oidc-secrets` lives in namespace `dex`.
- On a brand-new setup this namespace may not exist yet, so secret creation fails.
- The commands above remove that race and keep manual bootstrap to one short step.

## 6) Create required secrets (manual mode)

Export all required variables first:

```bash
export K8S_CONTEXT="admin@sidero"
export GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>"
export GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>"

# Generate strong client secrets (2 x random 32-byte values).
export ARGOCD_OIDC_CLIENT_SECRET="$(openssl rand -hex 32)"
export ARGO_WORKFLOWS_OIDC_CLIENT_SECRET="$(openssl rand -hex 32)"
```

If `openssl` is not available, use Python instead:

```bash
export ARGOCD_OIDC_CLIENT_SECRET="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
export ARGO_WORKFLOWS_OIDC_CLIENT_SECRET="$(python3 -c 'import secrets; print(secrets.token_hex(32))')"
```

Recommended: run the helper script (does bootstrap + secret creation + patching).

```bash
./scripts/bootstrap-sso.sh
```

The script uses these exported variables:

- `K8S_CONTEXT` (default: `admin@sidero`)
- `GOOGLE_CLIENT_ID` (required)
- `GOOGLE_CLIENT_SECRET` (required)
- `ARGOCD_OIDC_CLIENT_SECRET` (optional, auto-generated if unset)
- `ARGO_WORKFLOWS_OIDC_CLIENT_SECRET` (optional, auto-generated if unset)
- endpoint manifests must already be configured (no `example.com` placeholders)

Manual fallback (equivalent to the script):

Create/update Dex connector + static client secrets:

```bash
kubectl --context "${K8S_CONTEXT}" -n dex create secret generic dex-oidc-secrets \
  --from-literal=google-client-id="${GOOGLE_CLIENT_ID}" \
  --from-literal=google-client-secret="${GOOGLE_CLIENT_SECRET}" \
  --from-literal=argocd-oidc-client-secret="${ARGOCD_OIDC_CLIENT_SECRET}" \
  --from-literal=argo-workflows-oidc-client-secret="${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET}" \
  --dry-run=client -o yaml | kubectl --context "${K8S_CONTEXT}" apply -f -
```

Patch Argo CD OIDC client secret (must match Dex static client secret):

```bash
kubectl --context "${K8S_CONTEXT}" -n argocd patch secret argocd-secret \
  --type merge \
  -p "{\"stringData\":{\"oidc.dex.clientSecret\":\"${ARGOCD_OIDC_CLIENT_SECRET}\"}}"
```

Create/update Argo Workflows OIDC client secret (must match Dex static client secret):

```bash
kubectl --context "${K8S_CONTEXT}" -n argo create secret generic argo-workflows-sso-oidc \
  --from-literal=client-id="argo-workflows" \
  --from-literal=client-secret="${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET}" \
  --dry-run=client -o yaml | kubectl --context "${K8S_CONTEXT}" apply -f -
```

## 7) Validation

```bash
kubectl --context "${K8S_CONTEXT}" -n dex get deploy,pod,svc,ingress,certificate
kubectl --context "${K8S_CONTEXT}" -n argocd get cm argocd-cm argocd-rbac-cm
kubectl --context "${K8S_CONTEXT}" -n argo get cm workflow-controller-configmap deploy argo-server
```

Then test logins:

- Argo CD login via Dex button
- Argo Workflows login via SSO

## Notes

- Argo CD internal Dex deployment is intentionally scaled to `0`.
- `sso-admin@example.com` is a placeholder and must be replaced with your own
  identity before rollout.
- Endpoint hostnames are intentionally generic. Set your domain via
  `SSO_BASE_DOMAIN` / `DEX_HOST` / `ARGOCD_HOST` / `ARGO_WORKFLOWS_HOST` and
  run `./scripts/configure-sso-endpoints.sh`.
- Argo Workflows SSO RBAC maps your configured admin identity to admin and all
  other authenticated users to read-only.
- Rotate OAuth client secrets immediately if they were ever shared in plaintext.
- Current minimum manual input is only OAuth credentials and one-time secret creation.
  The rest is GitOps-managed by Argo CD.
