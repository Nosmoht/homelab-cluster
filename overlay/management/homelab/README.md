# homelab cluster overlay (CAPI + Sidero)

This folder contains the management-cluster manifests that define the `homelab`
workload cluster.

Pinned versions in these manifests:

- Talos: `v1.12.3`
- Kubernetes: `v1.35.0`
- Cilium: `v1.19.0` (inline manifest, kube-proxy replacement enabled, Hubble disabled)
- kubelet-serving-cert-approver: `v0.10.2`
- metrics-server: `v0.8.1`

## Cilium bootstrap notes

- Cilium is configured to talk to the API server via kubePrism (`localhost:7445`).
- Talos explicitly enables kubePrism to ensure Cilium can reach the API during bootstrap.

## Talos image factory schematic

- Schematic ID: `1a1a8fdf48ac2c0647ad26a55b1a476f1a1d8862a68a758ce45f0806eefa61e1`
- Initial/Upgrade installer image:
  - `factory.talos.dev/metal-installer/1a1a8fdf48ac2c0647ad26a55b1a476f1a1d8862a68a758ce45f0806eefa61e1:v1.12.3`
- PXE iPXE entrypoint:
  - `https://pxe.factory.talos.dev/pxe/1a1a8fdf48ac2c0647ad26a55b1a476f1a1d8862a68a758ce45f0806eefa61e1/v1.12.3/metal-amd64`
- PXE boot assets:
  - `https://pxe.factory.talos.dev/image/1a1a8fdf48ac2c0647ad26a55b1a476f1a1d8862a68a758ce45f0806eefa61e1/v1.12.3/kernel-amd64`
  - `https://pxe.factory.talos.dev/image/1a1a8fdf48ac2c0647ad26a55b1a476f1a1d8862a68a758ce45f0806eefa61e1/v1.12.3/initramfs-amd64.xz`
- Bootloader:
  - `sd-boot`
- System extensions:
  - `siderolabs/drbd`
  - `siderolabs/i915`
  - `siderolabs/intel-ice-firmware`
  - `siderolabs/intel-ucode`
  - `siderolabs/nvme-cli`

## Local-only files

`homelab-kubeconfig` and `homelab-talosconfig` are local helper files and are
ignored via repository `.gitignore`.
