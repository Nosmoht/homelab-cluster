# Dex SSO for Argo CD and Argo Workflows

This repo runs a standalone Dex in the management cluster and uses it as the
OIDC provider for:

- Argo CD (`https://argocd.homelab.ntbc.io`)
- Argo Workflows (`https://argoworkflows.homelab.ntbc.io`)

Dex endpoint:

- `https://dex.homelab.ntbc.io`

## 1) Google OAuth prerequisites

In Google Cloud Console, create an OAuth client of type **Web application**.

Required redirect URI:

- `https://dex.homelab.ntbc.io/callback`

## 2) Create required secrets (manual mode)

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

## 3) Validation

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
- Argo Workflows SSO RBAC maps `thomas.krahn.tk@gmail.com` to admin and all
  other authenticated users to read-only.
- Rotate OAuth client secrets immediately if they were ever shared in plaintext.
