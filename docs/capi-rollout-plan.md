# CAPI Rollout Orchestrator Workflow Plan (Option A)

## Summary
This plan defines an Argo Workflows **WorkflowTemplate** to orchestrate safe CAPI rolling replacements for a workload cluster (control plane first, then workers). The workflow does **not** patch CAPI objects. It monitors status and auto‑remediates stalled rollouts by deleting unhealthy Machines and rebooting their nodes via Talos. If a node is in Maintenance Mode, the workflow stops and requests manual intervention (no BMC).

## Goals / Success Criteria
- Manual submit and Argo Events trigger supported.
- Single input: `clusterName` (plus optional `clusterNamespace`, default `default`).
- Safe, sequential rollout (control plane → workers).
- Auto‑remediate on stall (delete Machine + reboot node).
- Fail fast if a node is in Maintenance Mode.

## Decisions & Constraints
- **Mode:** Orchestrate‑only (no CAPI patching).
- **Scope:** Control plane + workers.
- **Failure policy:** Auto‑remediate.
- **Triggering:** Manual + Argo Events.
- **Target selection:** by `cluster.x-k8s.io/cluster-name` label.
- **Talosconfig resolution:** label‑based only, no override parameters.
- **Reboot:** only during remediation; fails if Maintenance detected.

## Implementation Outline

### 1) WorkflowTemplate (namespace `argo`)
- File: `overlay/management/argo-workflows/capi-rollout-workflowtemplate.yaml`
- Parameters:
  - `clusterName` (required)
  - `clusterNamespace` (default `default`)
  - `pollInterval` (default `30s`)
  - `controlPlaneTimeout` (default `45m`)
  - `workersTimeout` (default `60m`)
  - `maxRemediations` (default `2`)
  - `rebootMode` (default `powercycle`)
- Auto‑resolve:
  - Talosconfig secret: label `cluster.x-k8s.io/cluster-name=<clusterName>` + name suffix `-talosconfig`.
- Steps:
  1) Resolve targets (TalosControlPlane + MachineDeployment) by label.
  2) Preflight safety checks (TCP `maxSurge=0`, MD `maxSurge=0/maxUnavailable=1`).
  3) Wait control plane rollout; remediate by deleting unhealthy CP Machine and rebooting its node.
  4) Wait worker rollout; same remediation logic.
  5) Summary output.

### 2) RBAC
- File: `overlay/management/argo-workflows/capi-rollout-rbac.yaml`
- ServiceAccount: `capi-rollout-runner` in `argo`.
- ClusterRole: read CAPI/TalosControlPlane + secrets; delete Machines.

### 3) Argo Events trigger
- Files:
  - `overlay/management/capi-rollout/event-source-capi-rollout.yaml`
  - `overlay/management/capi-rollout/sensor-capi-rollout.yaml`
  - `overlay/management/capi-rollout/rbac.yaml`
- Triggers on TalosControlPlane or MachineDeployment updates and submits workflow.

### 4) Kustomize + Apps
- Add workflow + rbac to `overlay/management/argo-workflows/kustomization.yaml`.
- Add `overlay/management/capi-rollout` kustomization.
- Add ArgoCD app `apps/management/capi-rollout.yaml`.

### 5) Safe rollout strategy
- Update `overlay/management/homelab/machine-deployment.yaml`:
  - `maxSurge: 0`
  - `maxUnavailable: 1`

## Validation
- `kustomize build overlay/management/argo-workflows`
- `kustomize build overlay/management/capi-rollout`
- Manual submit test in Argo:
  - `clusterName=homelab`

## Notes
- Workflow avoids overrides for talosconfig/kubeconfig; resolution is purely label‑based.
- If a node is in Maintenance Mode, the workflow fails with explicit manual action required.
