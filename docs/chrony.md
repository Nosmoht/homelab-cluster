# NTP service (chrony)

`overlay/management/chrony/` contains the NTP service for the private cloud
network.

Current behavior:

- Chrony is pinned to gateway node `sidero` (`kubernetes.io/hostname=sidero`).
- Chrony serves UDP/123 on host network address `10.0.0.1`.
- Upstream time source is Fritzbox `192.168.2.1`.
- NTP serving is restricted to `10.0.0.0/8` (`allow 10.0.0.0/8`).
- Deployment strategy is `Recreate` because host networking on UDP/123 prevents
  parallel rollout on a single-node gateway.
- Liveness checks verify `chronyd` is running.
- Readiness checks verify `chronyc tracking` responds.
- Argo CD application manifest is tracked in `apps/management/chrony.yaml`.
