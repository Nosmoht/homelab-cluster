# GitOps reconciliation for management apps

The parent Argo CD app `management-apps` (`apps/management-root.yaml`) manages
all core management child apps from `apps/management/`.

Current reconciliation setup:

- Parent app uses `project: default` so bootstrap works even if the
  `management` AppProject does not exist yet.
- `apps/management/project.yaml` creates the `management` AppProject in Git.
- Child apps run with automated sync (`prune: true`, `selfHeal: true`).
- Retry policy is enabled on child apps to handle transient failures.
- Sync waves enforce dependency ordering:
  - wave `-2`: `AppProject/management`
  - wave `0`: operators and infra (`cluster-api-operator`, `metallb-operator`,
    `chrony`, `dnsmasq-controller`)
  - wave `1`: dependent apps (`cluster-api`, `metallb`)

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
