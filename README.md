# cuvpn

A small fish wrapper around `openconnect` for the CU Boulder VPN. Adds:

- **Limited-mode route hygiene** — strips CU's over-broad route pushes (`10/8`, `192.168/16`, `172.16/12`) so they don't collide with home WireGuard, LAN, or Docker networks. Only actual CU CIDRs stay on the cuvpn interface.
- **Bounded DNS scope** — pins the cuvpn link's DNS to `*.colorado.edu` zones only and removes its default-route claim. Non-CU lookups stay on your primary resolver instead of racing against CU's DNS.
- **SSO via openconnect-lite** — browser- or terminal-based SAML auth.
- **Status / fix-routes** — re-strip routes and re-scope DNS post-connect if CU re-pushes.

## Requirements

- Arch / CachyOS (pacman-based)
- `fish`, `openconnect`, `vpnc`, `python` — pulled by the installer

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
cuvpn limited           # split-tunnel (default)
cuvpn full              # full-tunnel — clobbers default packet routing
cuvpn disconnect
cuvpn status
cuvpn fix-routes        # re-strip routes + re-scope DNS
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

## Logs

- vpnc-script actions: `/tmp/cuvpn-vpnc-script.log`
- fix-routes actions: `/tmp/cuvpn-fix-routes.log`

## License

MIT — see [LICENSE](LICENSE).
