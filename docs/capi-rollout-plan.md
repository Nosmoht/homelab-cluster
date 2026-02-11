# CAPI Rollout Orchestrator - No-Spare Hardening

## Summary
This runbook hardens the CAPI rollout orchestration for a no-spare-node topology.
The workflow enforces strict one-by-one node progress and prevents concurrent
rollout runs for the same cluster.

## Scope and defaults
- Workflow remains orchestrate-only (no patching of CAPI resources).
- Rollout order remains fixed: control plane, then workers.
- Automatic trigger is TCP-only.
- Default no-spare guard: `maxConcurrentUnavailable=1`.
- CAPI rollout strategy requirements remain mandatory:
  - TalosControlPlane: `maxSurge=0`
  - MachineDeployment: `maxSurge=0`, `maxUnavailable=1`

## WorkflowTemplate behavior
File: `overlay/management/argo-workflows/capi-rollout-workflowtemplate.yaml`

- Added parameter:
  - `maxConcurrentUnavailable` (default `"1"`).
- Added serialization:
  - `spec.synchronization.mutex` keyed by cluster namespace/name.
- Added runtime guard in polling loop:
  - count Machines with `Ready != True` for current scope.
  - count Machines with `metadata.deletionTimestamp` set for current scope.
  - fail fast when either value exceeds `maxConcurrentUnavailable`.
- Existing safety checks are still enforced before rollout wait/remediation starts.

## Trigger model
Files:
- `overlay/management/capi-rollout/event-source-capi-rollout.yaml`
- `overlay/management/capi-rollout/sensor-capi-rollout.yaml`

- `md-upsert` event source and trigger are removed.
- Only `tcp-upsert` events submit `capi-rollout-orchestrator`.
- Manual submit remains supported for worker-only or ad-hoc rollouts.

## Argo CD apply order for single-commit TCP+MD changes
Files:
- `overlay/management/homelab/talos-config-template.yaml`
- `overlay/management/homelab/machine-deployment.yaml`
- `overlay/management/homelab/talos-control-plane.yaml`

Required sync waves:
- TalosConfigTemplate: `argocd.argoproj.io/sync-wave: "-2"`
- MachineDeployment: `argocd.argoproj.io/sync-wave: "-1"`
- TalosControlPlane: `argocd.argoproj.io/sync-wave: "0"`

This guarantees that in a combined TCP+MD commit, MD/TalosConfig changes are
already applied when the TCP update event triggers the workflow.

## Validation
Run:

```bash
kustomize build overlay/management/homelab
kustomize build overlay/management/capi-rollout
kustomize build overlay/management/argo-workflows
```

Note: the argo-workflows overlay uses ksops; local build requires ksops support.

## Operational expectations
- Single combined TCP+MD commit:
  - exactly one active workflow per cluster (mutex).
  - no more than one unavailable/deleting node at any time per scope.
  - rollout sequence remains control plane then workers.
- Trigger storms (multiple TCP updates):
  - serialized execution; no concurrent cluster rollout runs.
- MD-only commit:
  - no automatic rollout trigger.
  - trigger manually via workflow submission when needed.
