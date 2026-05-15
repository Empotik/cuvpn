#!/usr/bin/env bash
# cuvpn installer for Arch / CachyOS hosts (pacman-based).
# Idempotent: safe to re-run after pulling updates.

set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR="${HOME}/.local/bin"
VENV_DIR="${HOME}/.local/share/cuvpn/venv"
SSO_BIN="${VENV_DIR}/bin/openconnect-lite"

if ! command -v pacman >/dev/null; then
    echo "This installer supports Arch / CachyOS via pacman. Aborting." >&2
    exit 1
fi

echo ">> Installing system dependencies (sudo)..."
sudo pacman -S --needed --noconfirm openconnect vpnc python fish

echo ">> Symlinking bin scripts into ${BIN_DIR}..."
mkdir -p "$BIN_DIR"
for src in "${REPO_DIR}/bin/cuvpn" "${REPO_DIR}/bin/cuvpn-vpnc-script"; do
    name=$(basename "$src")
    dest="${BIN_DIR}/${name}"
    if [[ -L "$dest" ]]; then
        ln -sfn "$src" "$dest"
        echo "  updated: $dest -> $src"
    elif [[ -e "$dest" ]]; then
        echo "  skip (real file, refusing to clobber): $dest" >&2
    else
        ln -s "$src" "$dest"
        echo "  created: $dest -> $src"
    fi
done

if [[ -x "$SSO_BIN" ]]; then
    echo ">> openconnect-lite venv already present at ${VENV_DIR}"
else
    echo ">> Creating openconnect-lite venv at ${VENV_DIR}..."
    mkdir -p "$(dirname -- "$VENV_DIR")"
    python -m venv "$VENV_DIR"
    "${VENV_DIR}/bin/pip" install --upgrade pip
    "${VENV_DIR}/bin/pip" install openconnect-lite
fi

cat <<'EOF'

Done. Next steps:
  - Configure your CU identikey (pick one):
      echo YOUR_IDENTIKEY > ~/.config/cuvpn/user      # per-host
      set -Ux CUVPN_USER YOUR_IDENTIKEY               # per-shell (fish)
      cuvpn limited --user YOUR_IDENTIKEY             # per-invocation
  - Connect:
      cuvpn limited
EOF
