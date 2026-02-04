# DNS/DHCP services (management cluster)

`overlay/management/dnsmasq-controller/` contains the private-cloud DNS/DHCP
configuration for the gateway node.

Current behavior:

- dnsmasq listens on `10.0.0.1` in host network mode.
- dnsmasq only serves on private-cloud interface `eth1` and excludes `eth0`
  and loopback `lo`.
- Upstream DNS forwarding uses Fritzbox (`192.168.2.1`).
- Local zone is authoritative for `homelab.ntbc.io` (`domain` + `local`).
- DNS safety/perf options are enabled (`domain-needed`, `stop-dns-rebind`,
  `cache-size=5000`, `local-ttl=60`, `neg-ttl=60`).
- DHCP runs in authoritative mode and provides:
  - static leases (`dhcp-range=10.0.0.0,static,infinite`)
  - small temporary dynamic pool (`10.0.0.240-10.0.0.249`, `12h`)
- Static DHCP/DNS host entries are present for `node-01` to `node-06`.
- The dnsmasq DaemonSet is pinned to the gateway node via
  `kubernetes.io/hostname=sidero`.
