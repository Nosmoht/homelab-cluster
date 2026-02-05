#!/usr/bin/env bash

set -euo pipefail

K8S_CONTEXT="${K8S_CONTEXT:-admin@sidero}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"
ARGOCD_OIDC_CLIENT_SECRET="${ARGOCD_OIDC_CLIENT_SECRET:-}"
ARGO_WORKFLOWS_OIDC_CLIENT_SECRET="${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANAGEMENT_ROOT_APP="${REPO_ROOT}/apps/management-root.yaml"
ARGOCD_RBAC_PATCH="${REPO_ROOT}/overlay/management/argocd/argocd-rbac-cm-sso-patch.yaml"
WORKFLOWS_RBAC_PATCH="${REPO_ROOT}/overlay/management/argo-workflows/sso-rbac.yaml"
SSO_ENDPOINT_FILES=(
  "${REPO_ROOT}/overlay/management/dex/configmap.yaml"
  "${REPO_ROOT}/overlay/management/dex/ingress.yaml"
  "${REPO_ROOT}/overlay/management/dex/certificate.yaml"
  "${REPO_ROOT}/overlay/management/argocd/argocd-cm-patch.yaml"
  "${REPO_ROOT}/overlay/management/argocd/ingress.yaml"
  "${REPO_ROOT}/overlay/management/argo-workflows/workflow-controller-configmap-sso-patch.yaml"
  "${REPO_ROOT}/overlay/management/argo-workflows/ingress.yaml"
  "${REPO_ROOT}/overlay/management/argo-workflows/certificate.yaml"
)

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' not found" >&2
    exit 1
  fi
}

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import secrets; print(secrets.token_hex(32))'
    return 0
  fi

  echo "error: neither openssl nor python3 is available to generate random secrets" >&2
  exit 1
}

require_cmd kubectl
require_cmd grep

if [[ -z "${GOOGLE_CLIENT_ID}" || -z "${GOOGLE_CLIENT_SECRET}" ]]; then
  cat >&2 <<'EOF'
error: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be exported.

Example:
  export GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>"
  export GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>"
EOF
  exit 1
fi

if grep -q "example.com" "${SSO_ENDPOINT_FILES[@]}"; then
  cat >&2 <<'EOF'
error: generic SSO endpoint placeholders detected (example.com).

Configure endpoint hosts first:
  export SSO_BASE_DOMAIN="<your-domain>"
  ./scripts/configure-sso-endpoints.sh

Then review/commit the manifest changes and re-run this script.
EOF
  exit 1
fi

if grep -q "sso-admin@example.com" "${ARGOCD_RBAC_PATCH}" "${WORKFLOWS_RBAC_PATCH}"; then
  cat >&2 <<'EOF'
warning: placeholder admin identity detected (sso-admin@example.com).
update these files before rollout:
  - overlay/management/argocd/argocd-rbac-cm-sso-patch.yaml
  - overlay/management/argo-workflows/sso-rbac.yaml
EOF
fi

if [[ -z "${ARGOCD_OIDC_CLIENT_SECRET}" ]]; then
  ARGOCD_OIDC_CLIENT_SECRET="$(generate_secret)"
fi

if [[ -z "${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET}" ]]; then
  ARGO_WORKFLOWS_OIDC_CLIENT_SECRET="$(generate_secret)"
fi

echo "using context: ${K8S_CONTEXT}"

for ns in argocd argo dex; do
  kubectl --context "${K8S_CONTEXT}" create namespace "${ns}" --dry-run=client -o yaml \
    | kubectl --context "${K8S_CONTEXT}" apply -f -
done

kubectl --context "${K8S_CONTEXT}" apply -f "${MANAGEMENT_ROOT_APP}"

kubectl --context "${K8S_CONTEXT}" -n argocd annotate application management-apps \
  argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true

kubectl --context "${K8S_CONTEXT}" -n dex create secret generic dex-oidc-secrets \
  --from-literal=google-client-id="${GOOGLE_CLIENT_ID}" \
  --from-literal=google-client-secret="${GOOGLE_CLIENT_SECRET}" \
  --from-literal=argocd-oidc-client-secret="${ARGOCD_OIDC_CLIENT_SECRET}" \
  --from-literal=argo-workflows-oidc-client-secret="${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET}" \
  --dry-run=client -o yaml | kubectl --context "${K8S_CONTEXT}" apply -f -

kubectl --context "${K8S_CONTEXT}" -n argocd patch secret argocd-secret \
  --type merge \
  -p "{\"stringData\":{\"oidc.dex.clientSecret\":\"${ARGOCD_OIDC_CLIENT_SECRET}\"}}"

kubectl --context "${K8S_CONTEXT}" -n argo create secret generic argo-workflows-sso-oidc \
  --from-literal=client-id="argo-workflows" \
  --from-literal=client-secret="${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET}" \
  --dry-run=client -o yaml | kubectl --context "${K8S_CONTEXT}" apply -f -

cat <<EOF
SSO bootstrap finished.

The following secrets were generated in-memory and used:
- ARGOCD_OIDC_CLIENT_SECRET
- ARGO_WORKFLOWS_OIDC_CLIENT_SECRET

If you did not provide them explicitly, store new values now for future re-runs.
EOF
