# Runbook: Three-Node Connectivity

## NC-M3B private control path

During NC-M3B, the controller on `mac-node` and the authenticated agents on
`asus-node` and `vps-node` use the private TLS/NKey/JWT NATS endpoint on
`asus-node`. The logical three-node paths are brokered through that ASUS
supporting service. This path does not require public DNS, Caddy, `frp`, or
authentik.

## Deferred NC-M3E edge path

```text
node agents -- outbound WSS/443 --> vps-node Caddy --> NATS/controller
asus services -- outbound frp/WSS/443 --> vps-node Caddy/frps
mac operator -- HTTPS/WSS direct or configured V2Box/SOCKS --> vps-node
```

Legacy SSH aliases remain recovery evidence, not the mature control transport.
Do not remove or rewrite them until the new path and independent recovery have
been verified.

## Inspection order

1. Mac local network, VPN interface/listeners, DNS, direct TCP/TLS/HTTP.
2. Mac configured SOCKS path with application-level TLS/HTTP verification.
3. VPS SSH identity and recovery, public listeners, Caddy/firewall/provider
   policy, then loopback services.
4. Asus LAN SSH identity and recovery, outbound DNS/TLS/WSS, sockets and any
   existing reverse tunnel.
5. Existing remote asus SSH path through VPS, without creating forwarding.

## Mutation gates

For Caddy, DNS, firewall, SSH, `frp`, or persistent service changes, prepare a
node-scoped plan with syntax validation, alternate recovery, client-side
verification, and rollback. Preserve the currently working path until the new
one passes from the operator network that matters.
