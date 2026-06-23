# cuvpn

A small fish wrapper around `openconnect` for the CU Boulder VPN. Adds:

- **Limited-mode route hygiene** — strips CU's over-broad route pushes (`10/8`, `192.168/16`, `172.16/12`) so they don't collide with home WireGuard, LAN, or Docker networks. Only actual CU CIDRs stay on the cuvpn interface.
- **Bounded DNS scope** — pins the cuvpn link's DNS to `*.colorado.edu` zones only and removes its default-route claim. Non-CU lookups stay on your primary resolver instead of racing against CU's DNS.
- **SSO via openconnect-lite** — browser- or terminal-based SAML auth.
- **Status / fix-routes** — re-strip routes and re-scope DNS post-connect if CU re-pushes.
- **Fast reconnect** — caches the VPN session cookie so `cuvpn reconnect` re-establishes a dropped tunnel without a fresh SSO/MFA round-trip.
- **Auto-reconnect** — an optional systemd user watchdog brings the tunnel back on its own if it drops, using a desktop password dialog (no passwordless sudo).

## Requirements

- Arch / CachyOS (pacman-based)
- `fish`, `openconnect`, `vpnc`, `python` — pulled by the installer
- For auto-reconnect (optional): a `systemd` user instance, a GUI askpass such as `ksshaskpass`, and `notify-send` (libnotify) for failure alerts

## Install

```sh
git clone git@github.com:Empotik/cuvpn.git
cd cuvpn
./install.sh
```

Pulls system packages, builds an `openconnect-lite` venv at `~/.local/share/cuvpn/venv/`, and symlinks `cuvpn` + `cuvpn-vpnc-script` into `~/.local/bin/`. Re-run after `git pull` to refresh.

## Configure your identikey

Pick one:

- Per-invocation: `cuvpn limited --user IDENTIKEY`
- Per-shell (fish, persistent): `set -Ux CUVPN_USER IDENTIKEY`
- Per-host: `mkdir -p ~/.config/cuvpn && echo IDENTIKEY > ~/.config/cuvpn/user`

## Usage

```
cuvpn limited                 # split-tunnel (default)
cuvpn full                    # full-tunnel — clobbers default packet routing
cuvpn reconnect               # re-establish a dropped tunnel, reusing the cached cookie (no SSO)
cuvpn disconnect
cuvpn forget                  # clear the cached VPN session cookie
cuvpn status
cuvpn watch [on|off|status]   # control the auto-reconnect watchdog
cuvpn fix-routes              # re-strip routes + re-scope DNS
```

## DNS policy

In limited mode the cuvpn link's DNS is scoped to `~int.colorado.edu`, `~ad.colorado.edu`, `~colorado.edu` (systemd-resolved routing domains) and `default-route` is set to `false`. Only matching queries route through cuvpn; everything else stays on the host's primary resolver.

Override the zone list with `CUVPN_DNS_ZONES` (env var, space-separated, `~`-prefixed):

```sh
CUVPN_DNS_ZONES='~int.colorado.edu ~colorado.edu' cuvpn limited
```

## Route allowlist

Default keep-list (limited mode):

- `128.138.0.0/16` — University of Colorado (ARIN: COLORADO)
- `198.11.16.0/20` — University of Colorado Boulder (NETBLK-CU-B)
- `198.59.7.0/24` — CU Boulder services
- `204.228.80.0/24` — CU Boulder
- `172.21.39.0/24` — cuvpn NAT pool

Override with `CUVPN_KEEP_PREFIXES` (env, space-separated CIDRs) or `~/.config/cuvpn/keep-prefixes` (one CIDR per line, `#` comments OK).

## Auto-reconnect

`cuvpn` connects in the background and, on a successful connect, arms a systemd
user watchdog (`cuvpn-watchdog.timer`) that re-establishes the tunnel if
openconnect exits. A manual `cuvpn disconnect` disarms it; there is no
connect-on-boot.

How a recovery works:

- The watchdog notices openconnect is gone and runs a **cookie-first** reconnect:
  it reuses the cached VPN session cookie, so no SSO/MFA. This works because a
  dropped tunnel never sends a clean logout, so CU keeps the session (and cookie)
  alive. A *clean* `cuvpn disconnect` does invalidate the cookie, so a reconnect
  after one falls back to SSO.
- openconnect needs root, and the watchdog runs unattended, so it uses `sudo -A`
  with a GUI askpass (e.g. KDE's `ksshaskpass`) — a desktop **password dialog**,
  not a passwordless sudo rule. Your sudo timestamp (~15 min) means rapid
  reconnects prompt at most once.
- If the cookie is truly dead (full re-auth needed), the watchdog sends a desktop
  notification telling you to run `cuvpn limited`, and disarms so it doesn't nag.

Tuning (all optional env vars):

- `CUVPN_AUTORECONNECT=0` — disable the watchdog entirely.
- `CUVPN_RECONNECT_TIMEOUT=SECONDS` — how long openconnect retries a broken link
  before exiting and handing off to the watchdog (default 60).
- `CUVPN_PROBE_TARGET=host:port` — enable an active liveness probe (a TCP connect
  routed through the tunnel) for faster detection of an alive-but-stalled link.
  Off by default to avoid false-positive reconnects.
- `CUVPN_ASKPASS=/path/to/askpass` — override the auto-detected GUI password helper.

## Logs

- vpnc-script actions: `/tmp/cuvpn-vpnc-script.log`
- fix-routes actions: `/tmp/cuvpn-fix-routes.log`
- watchdog: `journalctl --user -u cuvpn-watchdog.service`

## License

MIT — see [LICENSE](LICENSE).
