# CAPI -> Argo CD cluster bridge

This bridge registers workload clusters in Argo CD automatically.

## Flow

1. Cluster API/Talos control plane creates `<cluster>-kubeconfig` secret.
2. Argo Events `EventSource` watches Secret add/update/delete events.
3. Argo Events `Sensor` triggers Argo Workflows jobs.
4. Workflow creates/updates or deletes an Argo CD cluster secret in `argocd` namespace.

## Labels on generated Argo CD cluster secret

- `argocd.argoproj.io/secret-type=cluster`
- `homelab.ntbc.io/managed-by=capi-argocd-bridge`
- `homelab.ntbc.io/apps-enabled=false` (default gate)
- `cluster.x-k8s.io/cluster-name=<cluster-name>`
- `cluster.x-k8s.io/cluster-namespace=<cluster-namespace>`

## Verification

```bash
kubectl --context admin@sidero -n argo-events get eventbus,eventsource,sensor
kubectl --context admin@sidero -n argo-events get workflows
kubectl --context admin@sidero -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
```

Enable app rollout for a cluster:

```bash
kubectl --context admin@sidero -n argocd label secret <cluster-secret-name> \
  homelab.ntbc.io/apps-enabled=true --overwrite
```
