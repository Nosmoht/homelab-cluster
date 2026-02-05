# homelab-cluster

Bare-metal Kubernetes homelab on Talos Linux. This repo is the source of truth
after Day0 bootstrap and is designed for GitOps with Argo CD.

## What this repo contains

- Day0 bootstrap assets in `install/` (Talos configs, Makefile helpers).
- GitOps manifests in `base/` and `overlay/management/`.
- Platform components: Sidero / Cluster API / Cilium / LINBIT Linstor / MetalLB.

## Network overview (current homelab)

- Home LAN: `192.168.2.0/24`
  - Fritzbox gateway: `192.168.2.1`
  - Raspberry Pi mgmt: `192.168.2.60` (eth0, DHCP)
- Private cloud: `10.0.0.0/8`
  - Raspberry Pi: `10.0.0.1` (eth1, static), gateway + services
  - Nodes: `10.0.0.11`-`10.0.0.16`
- Port forwarding:
  - Talos API: TCP `50000` -> `192.168.2.60:50000`
  - Later: Fritzbox `443` -> MetalLB Ingress VIP
- Routing:
  - Fritzbox routes `10.0.0.0/8` via `192.168.2.60`
- DNS:
  - Zone `ntbc.io`, wildcard `*.homelab.ntbc.io` -> public Fritzbox IP

## Day0 vs Day2

Day0 (manual):
- Bootstrap the management cluster on the Raspberry Pi via `install/Makefile`
  and `talosctl`.

Day2 (GitOps):
- Argo CD manages everything in `overlay/management/` after bootstrap.
- Changes flow via PRs + CI.

Bootstrap for management Argo apps (one-time):

```bash
kubectl --context admin@sidero apply -f apps/management-root.yaml
```

After that, Argo manages everything listed in `apps/management/`.
Current core management apps in app-of-apps:
- `argocd` (self-managed from `overlay/management/argocd`)
- `dex` (standalone OIDC provider for Argo services)
- `argo-workflows`
- `argo-events`
- `capi-argocd-bridge` (sync CAPI kubeconfig secrets to Argo CD cluster secrets)
- `cert-manager` (from `overlay/management/cert-manager`)
- `homelab` (Cluster API + Sidero cluster resources from `overlay/management/homelab`)
- `chrony`
- `dnsmasq-controller`
- `cluster-api-operator`
- `cluster-api`
- `metallb-operator`
- `metallb`
- `workload-clusters` (ApplicationSet for non-management clusters)

Management UIs:
- Argo CD: `https://argocd.homelab.ntbc.io`
- Argo Workflows: `https://argoworkflows.homelab.ntbc.io`
- Dex: `https://dex.homelab.ntbc.io`

## Versions

Versions are pinned in `install/versions.mk` and used by the `install/Makefile`.
If a version is not derived from the repo, add a TODO and centralize it.
Argo CD base manifests are versioned in `base/argocd/`.

## Secrets

- `install/secrets.yaml` is sensitive and must not be committed.
- CI reconstructs it from GitHub Secrets:
  - `TALOS_BOOTSTRAP_SECRETS_YAML_B64` (base64 of `install/secrets.yaml`)
  - Optional: `TALOSCONFIG_B64`, `KUBECONFIG_B64`

## Local workflow

Copy the example env file and fill in your values:

```bash
cp install/.env.example install/.env
```

Common targets:

```bash
# Generate configs and validate them
make -C install config

# Generate + validate + dry-run apply
make -C install config-dry-run

# Day0: apply config + bootstrap
make -C install install

# Day2: apply changes
make -C install apply

# Upgrades
make -C install upgrade
make -C install upgrade-k8s

# Backup etcd snapshot
make -C install backup TALOS_NODE_ENDPOINT=sidero.homelab.ntbc.io
```

Key variables live in `install/.env`:
- `CLUSTER_NAME`
- `CLUSTER_NODE_IP`
- `CLUSTER_INSTALL_DISK`
- `CLUSTER_INSTALL_IMAGE_BASE`
- `CLUSTER_ADDITIONAL_SANS`
- `CLUSTER_ENDPOINT`
- `TALOS_NODE_ENDPOINT`

## CI

- PRs and pushes to `main` run `make config-dry-run`.
- The dry-run output is posted as a PR comment (redacted).
- PRs and pushes to `main` also run `cert-manager-secret-health` for
  cert-manager secret hygiene checks.
- See `docs/ci.md` for details.

## Backup runbook

- Backup/restore: `docs/backup-restore.md`
- Latest drill record: `docs/drills/2026-02-04-backup-restore-drill.md`

## Repo layout

- `install/`: bootstrap helpers (Makefile, patches, config generation)
- `base/`: reusable Kustomize bases
- `overlay/management/`: management cluster overlays and Argo CD apps
- `docs/`: operational notes (for example `docs/dnsmasq-controller.md`,
  `docs/chrony.md`, `docs/cert-manager.md`, `docs/workload-fleet.md`,
  `docs/capi-argocd-bridge.md`, `docs/sso.md`, `docs/sops.md`)

## Contributing

- Keep `install/` minimal and idempotent.
- Use GitOps for Day2 changes.
- Do not add plaintext secrets to the repo.
