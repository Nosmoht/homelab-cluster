# GitOps reconciliation for management apps

The parent Argo CD app `management-apps` (`apps/management-root.yaml`) manages
all core management child apps from `apps/management/`.

Current reconciliation setup:

- Parent app uses `project: default` so bootstrap works even if the
  `management` AppProject does not exist yet.
- `apps/management/project.yaml` creates the `management` AppProject in Git.
- Child apps run with automated sync (`prune: true`, `selfHeal: true`).
- `argocd` is self-managed from `overlay/management/argocd` and pinned to the
  latest stable base under `base/argocd/`.
- `argocd` uses sync option `Replace=true` to avoid client-side apply annotation
  limits on Argo CD CRDs and to keep migration from manual bootstrap stable.
- Retry policy is enabled on child apps to handle transient failures.
- `cluster-api` app uses `SkipDryRunOnMissingResource=true` because
  `CoreProvider/BootstrapProvider/ControlPlaneProvider/InfrastructureProvider`
  CRDs are introduced by the `cluster-api-operator` app.
- `cluster-api-operator` is pinned to `v0.15.1` until Talos/Sidero providers
  have stable `v1beta2` contract support. With operator `v0.25.0`, provider
  upgrades fail with `ComponentsUpgradeError` (`requested v1beta1`).
- Sync waves enforce dependency ordering:
  - wave `-2`: `AppProject/management`
  - wave `-1`: `argocd` (self-management app)
  - wave `0`: operators and infra (`cluster-api-operator`, `metallb-operator`,
    `chrony`, `dnsmasq-controller`)
  - wave `1`: dependent apps (`cluster-api`, `metallb`)

Inside the `cluster-api` app, provider installation is also wave-ordered:

- wave `0`: `CoreProvider` (`cluster-api`)
- wave `1`: Talos provider prerequisites (`Secret/sidero`) and Talos providers
  (`BootstrapProvider`, `ControlPlaneProvider`)
- wave `2`: `InfrastructureProvider/sidero`

## Manual reconciliation operations

List management apps and their sync/health state:

```bash
kubectl --context admin@sidero -n argocd get applications
```

Trigger a hard refresh on the parent app:

```bash
kubectl --context admin@sidero -n argocd annotate application management-apps \
  argocd.argoproj.io/refresh=hard --overwrite
```

Force a sync by patching an annotation bump (if needed):

```bash
kubectl --context admin@sidero -n argocd annotate application management-apps \
  homelab.ntbc.io/last-manual-sync="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
```
