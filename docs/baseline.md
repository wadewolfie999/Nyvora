# Observed Baseline

Last observation: 2026-08-21 during NC-M3 preflight. Runtime facts remain
time-sensitive.

## mac-node — confirmed

- Host: `Vaheeds-MacBook-Air`; macOS 26.5.2, Darwin 25.5.0 arm64.
- Apple M2, 8 cores, 8 GiB RAM; APFS root; SMART reported `Verified`.
- Wi-Fi address `192.168.1.56`; current default route was `utun4`.
- V2Box and PacketTunnel were running; SOCKS listened on `127.0.0.1:1087`.
- With VPN enabled, HTTPS and VPS SSH worked both through the default route and
  through explicit SOCKS. V2Box made raw `nc` port results unreliable: it
  reported synthetic connections where application protocols and asus probes
  showed no VPS service.
- Direct and ProxyJump SSH authenticated to the two Linux nodes using explicit
  local key files; the SSH agent held no identities.
- Go and Python were present. Docker, Caddy, `frp`, NATS, PostgreSQL, and `uv`
  were absent at NC-M1.
- NC-M2 installed Podman 6.1.0 and initialized the rootless `node-control`
  AppleHV machine with 2 CPUs, 3 GiB RAM, 1 GiB swap, and a 20 GiB disk. Its
  cgroup v2 tracer passed and was stopped after evidence collection.
- Hardware virtualization was available. FileVault was off.
- Time Machine was idle, but `tmutil latestbackup` failed to mount its backup
  destination. Recovery readiness is not established.

## vps-node — confirmed

- Hostname `wade`; operator account `ubuntu`; Ubuntu 26.04, kernel
  7.0.0-29-generic x86_64.
- 1 vCPU; 1,002,774,528 bytes RAM; no swap; about 18.6 GB free on a 25 GB disk.
- cgroup v2 mounted. Subuid/subgid ranges exist for `ubuntu`, but Podman and
  rootless helper programs are absent and an unprivileged user-namespace probe
  failed.
- Noninteractive sudo is available. User linger is off.
- OS listeners: public SSH on TCP/22, DNS/chrony loopback, and reverse SSH on
  `127.0.0.1:2222`. No Caddy, `frp`, NATS, PostgreSQL, authentik, controller,
  or LangGraph service was installed or listening.
- `asus-remote` successfully traversed the VPS loopback reverse endpoint.
- UFW was inactive; effective SSH permits public-key and password
  authentication, forwarding, and no gateway ports. Provider firewall/security
  policy remains unavailable.
- DNS and outbound HTTPS succeeded.

## asus-node — confirmed

- Hostname `wolfski`; operator account `wade`; Ubuntu 24.04, kernel
  6.8.0-138-generic x86_64.
- Intel i7-3630QM, 8 logical CPUs; about 8.2 GB RAM and 4.3 GB swap.
- Root filesystem: about 37.8 GB free; `/mnt/storage`: about 386.5 GB free.
- Drives: 119 GB SanDisk SSD and 699 GB Hitachi rotational disk. SMART tooling
  was absent and sudo was not noninteractive, so drive health is unverified.
- cgroup v2 and subuid/subgid ranges exist. Podman, newuidmap/newgidmap,
  fuse-overlayfs, slirp4netns, and pasta are absent; unprivileged user namespaces
  failed. User systemd runs, but linger is off.
- Rootful Docker is enabled/active. Existing Jellyfin runs in a Docker cgroup
  and listens on TCP/8096 plus UDP/7359. It is pre-existing state and is outside
  the Batch 1 migration scope.
- A separately delivered Tracker prototype is active as the user unit
  `tracker.service`, running Node from `/home/wade/apps/tracker-asus` and bound
  only to `127.0.0.1:3000`. Its root returned HTTP 200 during NC-M3 preflight.
  It is live user state and must not be stopped, replaced, or rebound by NC-M3.
- `127.0.0.1:42665` is also listening in `containerd.service` and returned HTTP
  404. The unprivileged account could not resolve its exact workload owner, so
  the port is reserved and must not be reused until ownership is proven.
- Direct LAN SSH and VPS ProxyJump SSH both authenticated.
- `asus-reverse-tunnel.service` maintains the current reverse SSH to
  `95.38.182.130`, exposing VPS loopback 2222. It has a history of 6004 restart
  attempts but was continuously active for about five hours at observation.
- Legacy `reverse-ssh.service` still loops through `autossh` toward
  `188.121.122.141`, including remote ports 2222 and 8096; that endpoint timed
  out repeatedly. Do not remove it until ownership/recovery is separately
  planned.
- Asus SOCKS `127.0.0.1:1081` was not listening and shell proxy variables were
  unset; direct DNS and HTTPS succeeded independently of the Mac.
- GPU hardware: Intel integrated graphics and NVIDIA GeForce GTX 660M using
  observable nouveau sensors; no `nvidia-smi`/CUDA path was available.
- Observed CPU package temperature was about 61–63°C and GPU about 41°C, with
  exported critical thresholds. No host guardian exists yet.
- A Jellyfin backup timer exists, but its successful restore behavior was not
  tested.

## Selected placement

`split-edge` is selected. The VPS cannot meet the current authentik minimum of
2 CPUs and 2 GB RAM before accounting for PostgreSQL, NATS, controller, Caddy,
or LangGraph. Asus is the only node with a plausible control-core capacity
envelope. This is a fixed placement selection, not an assertion that NC-M3 is
ready to apply.

## NC-M3 prerequisites still unmet

- No concrete wildcard domain or DNS records are recorded.
- Rootless Podman and required helper packages are absent on both Linux nodes;
  current rootless user-namespace probes fail.
- Mac local-container readiness is now verified only for the NC-M2 Podman
  Machine tracer; this does not satisfy either Linux node's rootless runtime
  prerequisite.
- SOPS/age recipients, NATS credentials, `frp` credential, PostgreSQL/authentik
  secrets, and Vahid OIDC bootstrap data do not exist.
- The selected asus control-core stack has not been measured on that node under
  explicit CPU and memory caps; the profile's capacity-reserve precondition is
  therefore not proven.
- Asus package installation requires interactive sudo or a separately approved
  privilege path.
- Provider firewall/recovery-console state is unverified.
- FileVault and Mac backup recovery are not ready.
- VPN-disabled operator behavior has not yet been tested; NC-M1 did not toggle
  the active VPN.

## Legacy evidence

The retired identifier `comp-node`, address `192.168.1.23`, and
`mac_remote_key` belong only to the 2026-08-08/13 record and are not accepted
for current operations.
