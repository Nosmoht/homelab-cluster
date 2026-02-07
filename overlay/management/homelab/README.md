# homelab cluster overlay (CAPI + Sidero)

This folder contains the management-cluster manifests that define the `homelab`
workload cluster.

Pinned versions in these manifests:

- Talos: `v1.12.2`
- Kubernetes: `v1.35.0`
- Cilium: `v1.19.0` (inline manifest, kube-proxy replacement enabled, Hubble disabled)
- kubelet-serving-cert-approver: `v0.10.2`
- metrics-server: `v0.8.1`

## Cilium bootstrap notes

- Cilium is configured to talk to the API server via kubePrism (`localhost:7445`).
- Talos explicitly enables kubePrism to ensure Cilium can reach the API during bootstrap.

## Talos image factory schematic

- Schematic ID: `e048aaf4461ff9f9576c9a42f760f2fef566559bd4933f322853ac291e46f238`
- Installer image:
  - `factory.talos.dev/installer/e048aaf4461ff9f9576c9a42f760f2fef566559bd4933f322853ac291e46f238:v1.12.2`
- System extensions:
  - `siderolabs/drbd`

## Local-only files

`homelab-kubeconfig` and `homelab-talosconfig` are local helper files and are
ignored via repository `.gitignore`.
