# Backup/restore drill report - February 4, 2026

Scope:

- Management cluster `sidero` (single-node Talos control plane)
- Drill type: backup execution + restore procedure walkthrough (non-destructive)

## Backup execution

Command:

```bash
make -C install backup TALOS_NODE_ENDPOINT=sidero.homelab.ntbc.io
```

Result:

- Snapshot file:
  `install/backups/sidero-etcd-20260204T065355Z.db`
- Snapshot size: `45,142,048` bytes
- etcd revision: `184785136`
- etcd hash (snapshot info): `8aff1370`
- SHA256:
  `8424cd802bb90bc8761751604562d65f6c3a1155fa0b8442b503d9975b3d8b9f`

Outcome: successful.

## Restore walkthrough

Because this is the live single-node management cluster, destructive restore was
not executed in production. The full command sequence was reviewed against
`docs/backup-restore.md` and is ready for maintenance-window execution.

Outcome: procedure validated as runnable; destructive execution deferred by
policy.
