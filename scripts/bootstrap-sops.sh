#!/usr/bin/env bash

set -euo pipefail

K8S_CONTEXT="${K8S_CONTEXT:-admin@sidero}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
SOPS_AGE_SECRET_NAME="${SOPS_AGE_SECRET_NAME:-sops-age}"
SOPS_CONFIG_FILE="${SOPS_CONFIG_FILE:-.sops.yaml}"
SOPS_AGE_KEY_FILE_LOCAL="${SOPS_AGE_KEY_FILE_LOCAL:-install/sops-age.key}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command '$1' not found" >&2
    exit 1
  fi
}

replace_recipient() {
  local recipient="$1"
  local file="$2"
  local escaped
  local tmp

  escaped="$(printf '%s\n' "${recipient}" | sed 's/[&/]/\\&/g')"
  tmp="${file}.tmp"

  sed "s/REPLACE_WITH_AGE_RECIPIENT/${escaped}/g" "${file}" > "${tmp}"
  mv "${tmp}" "${file}"
}

require_cmd age-keygen
require_cmd kubectl
require_cmd sed
require_cmd grep

if [[ ! -f "${SOPS_CONFIG_FILE}" ]]; then
  echo "error: ${SOPS_CONFIG_FILE} not found" >&2
  exit 1
fi

mkdir -p "$(dirname "${SOPS_AGE_KEY_FILE_LOCAL}")"

if [[ ! -f "${SOPS_AGE_KEY_FILE_LOCAL}" ]]; then
  echo "generating age key at ${SOPS_AGE_KEY_FILE_LOCAL}"
  age-keygen -o "${SOPS_AGE_KEY_FILE_LOCAL}" >/dev/null
  chmod 600 "${SOPS_AGE_KEY_FILE_LOCAL}"
fi

recipient="$(age-keygen -y "${SOPS_AGE_KEY_FILE_LOCAL}")"

if grep -q "REPLACE_WITH_AGE_RECIPIENT" "${SOPS_CONFIG_FILE}"; then
  echo "updating ${SOPS_CONFIG_FILE} with recipient ${recipient}"
  replace_recipient "${recipient}" "${SOPS_CONFIG_FILE}"
elif ! grep -q "${recipient}" "${SOPS_CONFIG_FILE}"; then
  cat >&2 <<EOF_WARN
warning: ${SOPS_CONFIG_FILE} does not contain this recipient:
  ${recipient}
ensure your creation_rules include it before encrypting new files.
EOF_WARN
fi

kubectl --context "${K8S_CONTEXT}" -n "${ARGOCD_NAMESPACE}" create secret generic "${SOPS_AGE_SECRET_NAME}" \
  --from-file=keys.txt="${SOPS_AGE_KEY_FILE_LOCAL}" \
  --dry-run=client -o yaml | kubectl --context "${K8S_CONTEXT}" apply -f -

cat <<EOF_OUT
SOPS bootstrap complete.

- age private key: ${SOPS_AGE_KEY_FILE_LOCAL}
- age recipient : ${recipient}
- cluster secret: ${ARGOCD_NAMESPACE}/${SOPS_AGE_SECRET_NAME}

Next steps:
1) Commit ${SOPS_CONFIG_FILE}
2) Encrypt secrets with: sops --encrypt --in-place <file>.sops.yaml
3) Sync Argo CD
EOF_OUT
