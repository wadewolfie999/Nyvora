# NC-M6b Tracker Android Private Client

Date: 2026-08-24

Disposition: `private-APK-built; device verification pending`.

## Scope

- New local client source: `/Users/vaheedgorgeen/libs/web-dev/tracker-android`.
- Android package: `studio.softorbit.tracker`, Capacitor `8.5.0`.
- Supported SDK envelope: `minSdk 33`, `targetSdk 36`, `compileSdk 36`.
- The existing Tracker application remains on `asus-node` loopback
  `127.0.0.1:3000`; no Tracker application or SQLite migration was made.
- Public ingress remains the VPS address `https://95.38.182.130` through the
  existing reverse tunnel and Caddy proxy.

## TLS and Android boundary

- Replaced the VPS leaf self-signed certificate with a leaf certificate issued
  by a dedicated private CA. Its SAN is `IP:95.38.182.130`; expiry is
  2027-09-24.
- Caddy uses `/etc/caddy/tracker-public.crt` and
  `/etc/caddy/tracker-public.key`; the previous leaf/key backups are
  `/etc/caddy/tracker-public.crt.pre-mobile-ca-20260824` and
  `/etc/caddy/tracker-public.key.pre-mobile-ca-20260824`.
- The CA private key and Android signing key are local, deployment-protected
  material outside the source tree. Only the public CA certificate is embedded
  at `android/app/src/main/res/raw/tracker_private_ca.pem`.
- Network security config disables cleartext and trusts that CA only. The
  release WebView disables file/content access, mixed content, third-party
  cookies, and debugging; it cancels TLS errors, confines in-WebView HTTPS
  requests to the Tracker origin, and opens external web links in the device
  browser.
- The manifest requests `INTERNET` only. AndroidX adds an app-private
  signature permission for its internal receiver; it is not a user-grantable
  permission.

## Build evidence

- `npx cap sync android` completed.
- `:app:assembleDebug` completed with JDK 21 and Android SDK 36.
- `:app:assembleRelease :app:bundleRelease` completed and the APK verified
  with APK Signature Scheme v2. The signer is the dedicated 4096-bit RSA
  Tracker Android release certificate.
- Release APK SHA-256:
  `18372e997205e311ecabfec8ea97b6a07bf890ff19fa6ec8a3c0aaeb0fb5dfaa`.
- Release AAB SHA-256:
  `7702c9388a1bedf175478e5c3ef814fe871522047ae43cc03a864456280db519`.

## Live evidence

- `curl --cacert` with the embedded CA returned HTTP `200` from
  `https://95.38.182.130`; default system trust rejected that same private CA
  chain.
- VPS Caddy was active, its configuration validated, and it listened locally
  on `*:443`; its active certificate issuer was `Tracker Android Private Root
  CA` with the expected IP SAN.
- `asus-node` reported `Linger=yes`; `tracker.service` and
  `tracker-edge-tunnel.service` were both enabled and active; the app returned
  HTTP `200` on ASUS loopback.

## Open verification and rollback

- No Android emulator or Xiaomi/Poco device was connected in this environment.
  The on-device sign-in, rotation, background/foreground, Wi-Fi/cellular, and
  offline-retry acceptance cases remain to be run before distributing the APK.
- A public TCP/80 probe from the Mac completed a TCP handshake but received an
  empty reply; packet capture on the VPS observed no corresponding packet and
  the VPS had no port-80 listener. This is an upstream/network-path anomaly,
  not proof of a closed public port. Confirm the provider firewall with an
  independent Internet probe before asserting the HTTPS-only edge condition.
- Rollback: restore the two `pre-mobile-ca-20260824` Caddy certificate files,
  validate/reload Caddy, and remove the private APK from test devices. The
  ASUS application, tunnel, database, and existing rollback directory are
  unchanged.
- This endpoint uses a private CA and IP address, so the AAB is not eligible
  for Google Play submission. Move to a publicly trusted domain certificate,
  publish a privacy policy, complete Data Safety, and create a reviewer account
  before the Play gate.
