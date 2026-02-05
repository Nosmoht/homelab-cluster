#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"
ARGOCD_OIDC_CLIENT_SECRET="${ARGOCD_OIDC_CLIENT_SECRET:-}"
ARGO_WORKFLOWS_OIDC_CLIENT_SECRET="${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET:-}"

DEX_SECRET_FILE="${DEX_SECRET_FILE:-${REPO_ROOT}/overlay/management/dex/dex-oidc-secrets.sops.yaml}"
ARGOCD_SECRET_FILE="${ARGOCD_SECRET_FILE:-${REPO_ROOT}/overlay/management/argocd/argocd-secret-sso.sops.yaml}"
WORKFLOWS_SECRET_FILE="${WORKFLOWS_SECRET_FILE:-${REPO_ROOT}/overlay/management/argo-workflows/argo-workflows-sso-oidc.sops.yaml}"

if [[ "${DEX_SECRET_FILE}" != /* ]]; then
  DEX_SECRET_FILE="${REPO_ROOT}/${DEX_SECRET_FILE}"
fi

if [[ "${ARGOCD_SECRET_FILE}" != /* ]]; then
  ARGOCD_SECRET_FILE="${REPO_ROOT}/${ARGOCD_SECRET_FILE}"
fi

if [[ "${WORKFLOWS_SECRET_FILE}" != /* ]]; then
  WORKFLOWS_SECRET_FILE="${REPO_ROOT}/${WORKFLOWS_SECRET_FILE}"
fi

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

encrypt_manifest() {
  local content="$1"
  local output="$2"
  local tmp_plain

  mkdir -p "$(dirname "${output}")"
  tmp_plain="$(dirname "${output}")/.tmp.$(basename "${output}")"
  printf '%s\n' "${content}" > "${tmp_plain}"
  if ! sops --encrypt --input-type yaml --output-type yaml "${tmp_plain}" > "${output}"; then
    rm -f "${tmp_plain}"
    return 1
  fi
  rm -f "${tmp_plain}"
}

require_cmd sops

if [[ -z "${GOOGLE_CLIENT_ID}" || -z "${GOOGLE_CLIENT_SECRET}" ]]; then
  cat >&2 <<'EOF_ERR'
error: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be exported.

Example:
  export GOOGLE_CLIENT_ID="<GOOGLE_CLIENT_ID>"
  export GOOGLE_CLIENT_SECRET="<GOOGLE_CLIENT_SECRET>"
EOF_ERR
  exit 1
fi

if [[ -z "${ARGOCD_OIDC_CLIENT_SECRET}" ]]; then
  ARGOCD_OIDC_CLIENT_SECRET="$(generate_secret)"
fi

if [[ -z "${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET}" ]]; then
  ARGO_WORKFLOWS_OIDC_CLIENT_SECRET="$(generate_secret)"
fi

encrypt_manifest "apiVersion: v1
kind: Secret
metadata:
  name: dex-oidc-secrets
  namespace: dex
  annotations:
    kustomize.config.k8s.io/behavior: replace
type: Opaque
stringData:
  google-client-id: \"${GOOGLE_CLIENT_ID}\"
  google-client-secret: \"${GOOGLE_CLIENT_SECRET}\"
  argocd-oidc-client-secret: \"${ARGOCD_OIDC_CLIENT_SECRET}\"
  argo-workflows-oidc-client-secret: \"${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET}\"" "${DEX_SECRET_FILE}"

encrypt_manifest "apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
  annotations:
    kustomize.config.k8s.io/behavior: merge
type: Opaque
stringData:
  oidc.dex.clientSecret: \"${ARGOCD_OIDC_CLIENT_SECRET}\"" "${ARGOCD_SECRET_FILE}"

encrypt_manifest "apiVersion: v1
kind: Secret
metadata:
  name: argo-workflows-sso-oidc
  namespace: argo
  annotations:
    kustomize.config.k8s.io/behavior: replace
type: Opaque
stringData:
  client-id: argo-workflows
  client-secret: \"${ARGO_WORKFLOWS_OIDC_CLIENT_SECRET}\"" "${WORKFLOWS_SECRET_FILE}"

cat <<EOF_OUT
Encrypted SSO secret manifests generated:
- ${DEX_SECRET_FILE}
- ${ARGOCD_SECRET_FILE}
- ${WORKFLOWS_SECRET_FILE}

Enable their generators in:
- overlay/management/dex/kustomization.yaml
- overlay/management/argocd/kustomization.yaml
- overlay/management/argo-workflows/kustomization.yaml

Then commit encrypted files and sync Argo CD.
EOF_OUT
