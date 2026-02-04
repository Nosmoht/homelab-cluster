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

## Versions

Versions are pinned in `install/versions.mk` and used by the `install/Makefile`.
If a version is not derived from the repo, add a TODO and centralize it.

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
- See `docs/ci.md` for details.

## Repo layout

- `install/`: bootstrap helpers (Makefile, patches, config generation)
- `base/`: reusable Kustomize bases
- `overlay/management/`: management cluster overlays and Argo CD apps
- `docs/`: operational notes (for example `docs/dnsmasq-controller.md`,
  `docs/chrony.md`)

## Contributing

- Keep `install/` minimal and idempotent.
- Use GitOps for Day2 changes.
- Do not add plaintext secrets to the repo.
