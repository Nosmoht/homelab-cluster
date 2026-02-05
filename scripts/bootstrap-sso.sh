#!/usr/bin/env bash

set -euo pipefail

K8S_CONTEXT="${K8S_CONTEXT:-admin@sidero}"
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"
ARGOCD_OIDC_CLIENT_SECRET="${ARGOCD_OIDC_CLIENT_SECRET:-}"
ARGO_WORKFLOWS_OIDC_CLIENT_SECRET="${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET:-}"
ARGOCD_WAIT_TIMEOUT_SECONDS="${ARGOCD_WAIT_TIMEOUT_SECONDS:-300}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANAGEMENT_ROOT_APP="${REPO_ROOT}/apps/management-root.yaml"

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

wait_for_argocd_secret() {
  local elapsed=0
  local sleep_seconds=5

  while ! kubectl --context "${K8S_CONTEXT}" -n argocd get secret argocd-secret >/dev/null 2>&1; do
    if (( elapsed >= ARGOCD_WAIT_TIMEOUT_SECONDS )); then
      echo "error: timed out after ${ARGOCD_WAIT_TIMEOUT_SECONDS}s waiting for argocd/argocd-secret" >&2
      exit 1
    fi

    echo "waiting for argocd/argocd-secret to exist..."
    sleep "${sleep_seconds}"
    elapsed=$((elapsed + sleep_seconds))
  done
}

require_cmd kubectl

if [[ -z "${GOOGLE_CLIENT_ID}" || -z "${GOOGLE_CLIENT_SECRET}" ]]; then
  cat >&2 <<'EOF'
error: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be exported.

Example:
  export GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>"
  export GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>"
EOF
  exit 1
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

wait_for_argocd_secret

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
