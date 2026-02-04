# Workload cluster fleet (ApplicationSet)

Management cluster uses an Argo CD `ApplicationSet` (`workload-clusters`) with the
`clusters` generator to create one root app per registered workload cluster.

## Generator selector

Only cluster secrets with this label are included:

```text
homelab.ntbc.io/apps-enabled=true
```

This keeps apps disabled for not-yet-ready clusters.

## Generated apps

For each matching cluster secret, the ApplicationSet creates:

- Application name: `workloads-<cluster-name>`
- Project: `workload-fleet`
- Source repo/path: `https://github.com/Nosmoht/homelab-apps.git` / `apps`
- Destination: `in-cluster` namespace `argocd`

## Enable apps for a cluster

```bash
kubectl --context admin@sidero -n argocd label secret <cluster-secret-name> \
  homelab.ntbc.io/apps-enabled=true --overwrite
```

## Disable apps for a cluster

```bash
kubectl --context admin@sidero -n argocd label secret <cluster-secret-name> \
  homelab.ntbc.io/apps-enabled-
```

## Verify

```bash
kubectl --context admin@sidero -n argocd get applicationset workload-clusters
kubectl --context admin@sidero -n argocd get applications | grep '^workloads-'
```

## Migration from legacy `homelab-apps`

If the old static root app exists, remove it (and the old homelab cert-manager
child app) to avoid name collisions with management `cert-manager`:

```bash
kubectl --context admin@sidero -n argocd delete application homelab-apps cert-manager
```
