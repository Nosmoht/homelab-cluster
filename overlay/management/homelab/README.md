# homelab cluster overlay (CAPI + Sidero)

This folder contains the management-cluster manifests that define the `homelab`
workload cluster.

Pinned versions in these manifests:

- Talos: `v1.12.4`
- Kubernetes: `v1.35.0`
- Cilium: `v1.19.0` (inline manifest, kube-proxy replacement enabled, Hubble disabled)
- kubelet-serving-cert-approver: `v0.10.2`
- metrics-server: `v0.8.1`

## ServerClass layout

- `homelab-cp-i5`: control plane nodes (`Intel(R) Core(TM) i5-7400T CPU @ 2.40GHz`)
- `homelab-compute-slow`: worker nodes (`Intel(R) Core(TM) i3-6100T CPU @ 3.20GHz`)
- `homelab-compute-medium`: worker nodes (`Intel(R) Core(TM) i5-7500T CPU @ 2.70GHz`)
- `homelab-compute-fast`: worker nodes (`Intel(R) Core(TM) i7-7700T CPU @ 2.90GHz`)
- `homelab-compute-gpu`: dedicated GPU worker class

## Talos image factory schematics

- Standard schematic ID: `1a1a8fdf48ac2c0647ad26a55b1a476f1a1d8862a68a758ce45f0806eefa61e1`
  - Extensions:
    - `siderolabs/drbd`
    - `siderolabs/i915`
    - `siderolabs/intel-ice-firmware`
    - `siderolabs/intel-ucode`
    - `siderolabs/nvme-cli`
- GPU schematic ID: `21673c24c2599d637798768b9b706349ca91161583257179df72d775af9348c0`
  - Extensions:
    - all standard extensions
    - `siderolabs/nonfree-kmod-nvidia-lts`
    - `siderolabs/nvidia-container-toolkit-lts`

## Environments

- `homelab-compute` uses the standard (non-GPU) PXE kernel/initramfs.
- `homelab-gpu` uses the GPU PXE kernel/initramfs.

## Worker bootstrap templates

- `homelab-workers-standard-v1-12-4-1`: non-GPU installer image.
- `homelab-compute-gpu-v1-12-4-1`: GPU installer image.

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
