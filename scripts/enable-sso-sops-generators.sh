#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ensure_generator() {
  local file="$1"
  local entry="$2"
  local tmp

  tmp="${file}.tmp"

  awk -v entry="${entry}" '
    BEGIN {
      in_generators = 0
      found = 0
      generators_seen = 0
    }

    /^generators:[[:space:]]*$/ {
      generators_seen = 1
      in_generators = 1
      print
      next
    }

    in_generators && /^[^[:space:]].*:[[:space:]]*$/ {
      if (!found) {
        print "  - " entry
        found = 1
      }
      in_generators = 0
      print
      next
    }

    in_generators && /^[[:space:]]*-[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      if (line == entry) {
        found = 1
      }
      print
      next
    }

    {
      print
    }

    END {
      if (in_generators && !found) {
        print "  - " entry
        found = 1
      }

      if (!generators_seen) {
        print ""
        print "generators:"
        print "  - " entry
      }
    }
  ' "${file}" > "${tmp}"

  mv "${tmp}" "${file}"
}

ensure_generator "${REPO_ROOT}/overlay/management/dex/kustomization.yaml" "dex-oidc-secrets-generator.yaml"
ensure_generator "${REPO_ROOT}/overlay/management/argocd/kustomization.yaml" "argocd-secret-sso-generator.yaml"
ensure_generator "${REPO_ROOT}/overlay/management/argo-workflows/kustomization.yaml" "argo-workflows-sso-oidc-generator.yaml"

echo "Enabled KSOPS generators in dex/argocd/argo-workflows kustomizations."
