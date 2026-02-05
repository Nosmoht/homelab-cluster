#!/usr/bin/env bash

set -euo pipefail

SSO_BASE_DOMAIN="${SSO_BASE_DOMAIN:-example.com}"
DEX_HOST="${DEX_HOST:-dex.${SSO_BASE_DOMAIN}}"
ARGOCD_HOST="${ARGOCD_HOST:-argocd.${SSO_BASE_DOMAIN}}"
ARGO_WORKFLOWS_HOST="${ARGO_WORKFLOWS_HOST:-argoworkflows.${SSO_BASE_DOMAIN}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

escape_sed() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

apply_sed() {
  local file="$1"
  shift

  local tmp="${file}.tmp"
  sed -E "$@" "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

DEX_HOST_ESCAPED="$(escape_sed "${DEX_HOST}")"
ARGOCD_HOST_ESCAPED="$(escape_sed "${ARGOCD_HOST}")"
ARGO_WORKFLOWS_HOST_ESCAPED="$(escape_sed "${ARGO_WORKFLOWS_HOST}")"

apply_sed "${REPO_ROOT}/overlay/management/dex/configmap.yaml" \
  -e "s#^([[:space:]]*issuer: )https://[^[:space:]]+#\\1https://${DEX_HOST_ESCAPED}#" \
  -e "s#^([[:space:]]*redirectURI: )https://[^[:space:]]+/callback#\\1https://${DEX_HOST_ESCAPED}/callback#" \
  -e "s#^([[:space:]]*-[[:space:]]*)https://[^[:space:]]+/auth/callback#\\1https://${ARGOCD_HOST_ESCAPED}/auth/callback#" \
  -e "s#^([[:space:]]*-[[:space:]]*)https://[^[:space:]]+/oauth2/callback#\\1https://${ARGO_WORKFLOWS_HOST_ESCAPED}/oauth2/callback#"

apply_sed "${REPO_ROOT}/overlay/management/dex/ingress.yaml" \
  -e "s#^([[:space:]]*-[[:space:]]*host:[[:space:]]*).*\$#\\1${DEX_HOST_ESCAPED}#" \
  -e "s#^([[:space:]]*-[[:space:]]*)[A-Za-z0-9.-]+\\.[A-Za-z0-9.-]+\$#\\1${DEX_HOST_ESCAPED}#"

apply_sed "${REPO_ROOT}/overlay/management/dex/certificate.yaml" \
  -e "s#^([[:space:]]*-[[:space:]]*)[A-Za-z0-9.-]+\\.[A-Za-z0-9.-]+\$#\\1${DEX_HOST_ESCAPED}#"

apply_sed "${REPO_ROOT}/overlay/management/argocd/argocd-cm-patch.yaml" \
  -e "s#^([[:space:]]*url: )https://[^[:space:]]+#\\1https://${ARGOCD_HOST_ESCAPED}#" \
  -e "s#^([[:space:]]*issuer: )https://[^[:space:]]+#\\1https://${DEX_HOST_ESCAPED}#"

apply_sed "${REPO_ROOT}/overlay/management/argocd/ingress.yaml" \
  -e "s#^([[:space:]]*-[[:space:]]*host:[[:space:]]*).*\$#\\1${ARGOCD_HOST_ESCAPED}#" \
  -e "s#^([[:space:]]*-[[:space:]]*)[A-Za-z0-9.-]+\\.[A-Za-z0-9.-]+\$#\\1${ARGOCD_HOST_ESCAPED}#"

apply_sed "${REPO_ROOT}/overlay/management/argo-workflows/ingress.yaml" \
  -e "s#^([[:space:]]*-[[:space:]]*host:[[:space:]]*).*\$#\\1${ARGO_WORKFLOWS_HOST_ESCAPED}#" \
  -e "s#^([[:space:]]*-[[:space:]]*)[A-Za-z0-9.-]+\\.[A-Za-z0-9.-]+\$#\\1${ARGO_WORKFLOWS_HOST_ESCAPED}#"

apply_sed "${REPO_ROOT}/overlay/management/argo-workflows/certificate.yaml" \
  -e "s#^([[:space:]]*-[[:space:]]*)[A-Za-z0-9.-]+\\.[A-Za-z0-9.-]+\$#\\1${ARGO_WORKFLOWS_HOST_ESCAPED}#"

apply_sed "${REPO_ROOT}/overlay/management/argo-workflows/workflow-controller-configmap-sso-patch.yaml" \
  -e "s#^([[:space:]]*issuer: )https://[^[:space:]]+#\\1https://${DEX_HOST_ESCAPED}#" \
  -e "s#^([[:space:]]*redirectUrl: )https://[^[:space:]]+/oauth2/callback#\\1https://${ARGO_WORKFLOWS_HOST_ESCAPED}/oauth2/callback#"

cat <<EOF
SSO endpoint configuration updated:
- DEX_HOST=${DEX_HOST}
- ARGOCD_HOST=${ARGOCD_HOST}
- ARGO_WORKFLOWS_HOST=${ARGO_WORKFLOWS_HOST}

Review and commit changed files before Argo CD sync.
EOF
