# kube-bench workflow

The management cluster ships a reusable Argo Workflows template that runs
kube-bench against a workload cluster and captures the output.

What it does:

- Creates a kube-bench DaemonSet on the target cluster.
- Waits for pods to start, collects logs, and stores them in a ConfigMap.
- Deletes the DaemonSet on exit.

The workflow template is named `kube-bench-run` in the `argo` namespace.

## Running the workflow

1. Open Argo Workflows UI and submit from template `kube-bench-run`.
2. Optionally override parameters (defaults shown below).

Default parameters:

- `kubeconfigSecretNamespace`: `default`
- `kubeconfigSecretName`: `homelab-kubeconfig`
- `kubeconfigSecretKey`: `value`
- `kubeBenchNamespace`: `kube-system`
- `kubeBenchDaemonsetName`: `kube-bench`
- `kubeBenchImage`: `aquasec/kube-bench:v0.14.1`
- `kubeBenchBenchmark`: `cis-1.11`
- `waitSeconds`: `90`

## Results

The workflow stores the collected output in a ConfigMap named:

```
argo/kube-bench-results-<workflow-name>
```

You can read it with:

```bash
kubectl --context admin@sidero -n argo get configmap \
  kube-bench-results-<workflow-name> \
  -o jsonpath='{.data.kube-bench\.log}'
```

## Notes

- kube-bench relies on host file paths under `/etc` and `/var`. On Talos,
  some checks may be skipped or reported as failures due to missing paths.
- The template uses the CAPI kubeconfig secret in the management cluster to
  reach workload clusters. Update the secret name when running against a
  different cluster.
