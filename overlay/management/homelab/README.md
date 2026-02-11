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

## Etcd metrics for monitoring

- Talos control-plane nodes expose etcd metrics via
  `cluster.etcd.extraArgs.listen-metrics-urls=http://0.0.0.0:2381`.
- `kube-prometheus-stack` scrapes the control-plane node IPs on port `2381`
  through `kubeEtcd.endpoints`.
- Changes to the Talos control-plane config must roll out via CAPI/Talos
  Provider (not `talosctl upgrade`).

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

## Rollout data safety (LINSTOR)

- `source.hostDevices` for LINSTOR is intentionally enabled (automatic PV/VG/LVM
  provisioning).
- For machine remediation, the rollout workflow must evacuate LINSTOR resources
  from the target node before `Machine` deletion and reboot.
- After node rejoin, the workflow restores the LINSTOR node and waits for a
  settled state before proceeding to the next node.
- This fail-safe flow prevents storage data loss during reinstall/remediation
  in no-spare-node operation.

## Local ops config

Operational checks can use the local helper configs in the repository root:

- `/Users/thomaskrahn/workspace/sidero-apps/kubeconfig-homelab`
- `/Users/thomaskrahn/workspace/sidero-apps/talosconfig-homelab`

## Local-only files

`homelab-kubeconfig` and `homelab-talosconfig` are local helper files and are
ignored via repository `.gitignore`.
