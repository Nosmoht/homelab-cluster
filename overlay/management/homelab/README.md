# homelab cluster overlay (CAPI + Sidero)

This folder contains the management-cluster manifests that define the `homelab`
workload cluster.

Pinned versions in these manifests:

- Talos: `v1.12.2`
- Kubernetes: `v1.35.0`
- Cilium: `v1.19.0` (inline manifest, kube-proxy replacement enabled, Hubble disabled)
- kubelet-serving-cert-approver: `v0.10.2`
- metrics-server: `v0.8.1`

## Talos image factory schematic

- Schematic ID: `797d93756de3d25be5830c940abc717e72ca4c7130c70ab292b7a337888f322a`
- Installer image:
  - `factory.talos.dev/installer/797d93756de3d25be5830c940abc717e72ca4c7130c70ab292b7a337888f322a:v1.12.2`

## Local-only files

`homelab-kubeconfig` and `homelab-talosconfig` are local helper files and are
ignored via repository `.gitignore`.
