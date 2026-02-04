# DNS/DHCP services (management cluster)

`overlay/management/dnsmasq-controller/` contains the private-cloud DNS/DHCP
configuration for the gateway node.

Current behavior:

- dnsmasq listens on `10.0.0.1` in host network mode.
- Upstream DNS forwarding uses Fritzbox (`192.168.2.1`).
- The dnsmasq DaemonSet is pinned to the gateway node via
  `kubernetes.io/hostname=sidero`.
