# Workload cluster fleet (ApplicationSet)

Management cluster uses an Argo CD `ApplicationSet` (`workload-clusters`) with the
`clusters` generator to create one root app per registered workload cluster.

## Cluster registration bridge

Workload clusters are registered automatically via Argo Events + Argo Workflows:

- Source: CAPI kubeconfig secret `<cluster-name>-kubeconfig` (`type: cluster.x-k8s.io/secret`)
- Target: Argo CD cluster secret in `argocd` namespace
- Bridge labels each target secret with:
  - `argocd.argoproj.io/secret-type=cluster`
  - `homelab.ntbc.io/managed-by=capi-argocd-bridge`
  - `homelab.ntbc.io/apps-enabled=false` (default gate)

This keeps app rollout disabled by default until the cluster is ready.

## Generator selector

Only cluster secrets with these labels are included:

```text
argocd.argoproj.io/secret-type=cluster
homelab.ntbc.io/apps-enabled=true
```

This keeps apps disabled for not-yet-ready clusters.

## Generated apps

For each matching cluster secret, the ApplicationSet creates:

- Application name: `workloads-<cluster-name-normalized>`
- Project: `workload-fleet`
- Source repo/path: `https://github.com/Nosmoht/homelab-apps.git` / `apps`
- Destination: target cluster API server from the cluster secret, namespace `argocd`

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
kubectl --context admin@sidero -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
```

## Migration from legacy `homelab-apps`

If the old static root app exists, remove it (and the old homelab cert-manager
child app) to avoid name collisions with management `cert-manager`:

```bash
kubectl --context admin@sidero -n argocd delete application homelab-apps cert-manager
```
