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

Create Dex connector + static client secrets:

```bash
kubectl --context admin@sidero -n dex create secret generic dex-oidc-secrets \
  --from-literal=google-client-id='<GOOGLE_CLIENT_ID>' \
  --from-literal=google-client-secret='<GOOGLE_CLIENT_SECRET>' \
  --from-literal=argocd-oidc-client-secret='<RANDOM_SECRET>' \
  --from-literal=argo-workflows-oidc-client-secret='<RANDOM_SECRET>'
```

Create Argo CD OIDC client secret (must match Dex static client secret):

```bash
kubectl --context admin@sidero -n argocd patch secret argocd-secret \
  --type merge \
  -p '{"stringData":{"oidc.dex.clientSecret":"<SAME_ARGOCD_SECRET_AS_IN_DEX>"}}'
```

Create Argo Workflows OIDC client secret (must match Dex static client secret):

```bash
kubectl --context admin@sidero -n argo create secret generic argo-workflows-sso-oidc \
  --from-literal=client-id='argo-workflows' \
  --from-literal=client-secret='<SAME_WORKFLOWS_SECRET_AS_IN_DEX>'
```

## 3) Validation

```bash
kubectl --context admin@sidero -n dex get deploy,pod,svc,ingress,certificate
kubectl --context admin@sidero -n argocd get cm argocd-cm argocd-rbac-cm
kubectl --context admin@sidero -n argo get cm workflow-controller-configmap deploy argo-server
```

Then test logins:

- Argo CD login via Dex button
- Argo Workflows login via SSO

## Notes

- Argo CD internal Dex deployment is intentionally scaled to `0`.
- Argo Workflows SSO RBAC maps `thomas.krahn.tk@gmail.com` to admin and all
  other authenticated users to read-only.
- Rotate OAuth client secrets immediately if they were ever shared in plaintext.
