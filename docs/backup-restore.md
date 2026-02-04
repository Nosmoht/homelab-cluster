# Backup and restore runbook (Talos single-node management cluster)

This runbook covers disaster recovery for the management cluster on `sidero`.

Assumptions:

- Talos API is reachable from outside via `sidero.homelab.ntbc.io:50000`.
- Kubernetes API (`10.0.0.1:6443`) is only reachable from the private network.
- Git remains the source of truth for Day2 manifests.

## 1) Backup procedure (etcd snapshot)

Prerequisites:

- `install/talosconfig` exists and can reach Talos API.
- `install/.env` exists (or `install/.env.example` is valid for this homelab).

Create snapshot + checksum:

```bash
make -C install backup TALOS_NODE_ENDPOINT=sidero.homelab.ntbc.io
```

Output is written to `install/backups/`:

- `<cluster>-etcd-<timestamp>.db`
- `<cluster>-etcd-<timestamp>.db.sha256`

Verify checksum manually (optional):

```bash
sha256sum -c install/backups/<file>.db.sha256
```

(Use `shasum -a 256 -c ...` on systems without `sha256sum`.)

Retention cleanup:

```bash
make -C install backup-prune BACKUP_RETENTION_DAYS=30
```

## 2) Restore procedure (disaster recovery)

Use this when etcd state is corrupted/lost and you need to recover control
plane state from snapshot.

1. Put the node into a maintenance window and stop normal change operations.
2. Ensure Talos API access works to `sidero.homelab.ntbc.io:50000`.
3. Re-apply Talos machine config if needed:

   ```bash
   make -C install apply TALOS_NODE_ENDPOINT=sidero.homelab.ntbc.io
   ```

4. Recover etcd from snapshot:

   ```bash
   talosctl --talosconfig install/talosconfig \
     --nodes sidero.homelab.ntbc.io \
     bootstrap --recover-from install/backups/<snapshot>.db
   ```

5. Re-generate kubeconfig and verify control plane:

   ```bash
   talosctl --talosconfig install/talosconfig \
     --nodes sidero.homelab.ntbc.io kubeconfig install/kubeconfig-homelab

   kubectl --kubeconfig install/kubeconfig-homelab get nodes
   kubectl --kubeconfig install/kubeconfig-homelab -n argocd get applications
   ```

6. Verify Argo reconciliation and service health (`chrony`,
   `dnsmasq-controller`, `metallb`, `cluster-api`).

## 3) Drill policy

- Run backup drill at least monthly and before Talos/Kubernetes upgrades.
- Document every drill in `docs/drills/` with timestamp, snapshot hash,
  and verification outcome.

See the latest drill report:

- `docs/drills/2026-02-04-backup-restore-drill.md`
