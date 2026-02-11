# CAPI Rollout Orchestrator Hardening (No-Spare + LINSTOR Safety)

## Summary
This runbook defines the safety model for rollout orchestration in a no-spare
topology:

- keep strict one-node-at-a-time rollout behavior,
- serialize cluster rollouts with an Argo mutex,
- enforce a fail-closed LINSTOR evacuation and restore flow before any machine
  remediation (`delete machine` + `talosctl reboot`).

`source.hostDevices` remains intentionally enabled in the LINSTOR app because it
is required for automatic PV/VG/LVM provisioning.

## Core guarantees
- Rollout order stays fixed: control plane, then workers.
- Automatic trigger stays TCP-only.
- No more than one unavailable/deleting node per scope.
- No machine remediation starts while LINSTOR reports faulty resources.
- No machine remediation starts before the target node is evacuated from
  `lvm-thick`.
- After reboot, LINSTOR node restore and cluster settle checks must pass before
  proceeding.

## WorkflowTemplate behavior
File: `overlay/management/argo-workflows/capi-rollout-workflowtemplate.yaml`

### Existing safety checks (unchanged)
- TalosControlPlane requires `maxSurge=0`.
- MachineDeployment requires `maxSurge=0`, `maxUnavailable=1`.
- Runtime guard enforces `maxConcurrentUnavailable`.
- Workflow mutex key: `capi-rollout-<namespace>-<cluster>`.

### New LINSTOR parameters
- `linstorGuardEnabled` (default `"true"`).
- `linstorNamespace` (default `piraeus-datastore`).
- `linstorControllerSelector` (default `app.kubernetes.io/component=linstor-controller`).
- `linstorStoragePool` (default `lvm-thick`).
- `linstorEvacuationTimeout` (default `45m`).
- `linstorSettleTimeout` (default `30m`).

### Remediation flow (timeout path)
1. Select unhealthy machine as before.
2. Resolve node name and node IP.
3. If `linstorGuardEnabled=true`:
   - assert global LINSTOR health (`linstor resource list --faulty` is empty),
   - evacuate target node (`linstor node evacuate <node>`),
   - wait until no `lvm-thick` resource rows remain on target node.
4. Delete machine.
5. Reboot node via Talos (`talosctl reboot --mode=<...> --wait=true --timeout <...>`).
6. If `linstorGuardEnabled=true`:
   - restore node (`linstor node restore <node>`),
   - wait until LINSTOR is settled (no active `Connecting`/`Sync`/`DELETING`
     states),
   - re-check global faulty resources.
7. Continue polling rollout progress.

All LINSTOR failures are fail-fast and stop remediation before destructive
actions.

## Trigger model
Files:
- `overlay/management/capi-rollout/event-source-capi-rollout.yaml`
- `overlay/management/capi-rollout/sensor-capi-rollout.yaml`

- `md-upsert` is not an automatic trigger.
- only `tcp-upsert` submits `capi-rollout-orchestrator`.
- manual submit remains available for ad-hoc worker rollouts.

## Single-commit TCP+MD ordering
Files:
- `overlay/management/homelab/talos-config-template.yaml`
- `overlay/management/homelab/machine-deployment.yaml`
- `overlay/management/homelab/talos-control-plane.yaml`

Required Argo CD sync waves:
- TalosConfigTemplate: `-2`
- MachineDeployment: `-1`
- TalosControlPlane: `0`

This guarantees that combined TCP+MD changes are applied in correct order before
the TCP-triggered rollout starts.

## Validation
```bash
kustomize build overlay/management/homelab
kustomize build overlay/management/capi-rollout
kustomize build overlay/management/argo-workflows
```

Note: the argo-workflows overlay uses ksops; local build requires ksops support.

## Operational checks
Use local workload credentials for manual checks:

```bash
export KUBECONFIG=/Users/thomaskrahn/workspace/sidero-apps/kubeconfig-homelab
export TALOSCONFIG=/Users/thomaskrahn/workspace/sidero-apps/talosconfig-homelab
```

## Expected scenarios
- Happy path:
  evacuation succeeds, remediation completes, restore settles, rollout resumes.
- Evacuation blocked:
  workflow aborts before machine delete/reboot.
- LINSTOR faulty:
  workflow aborts before machine delete/reboot.
- Restore/settle timeout:
  workflow aborts after reboot with explicit failure.
