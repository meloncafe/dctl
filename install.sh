#!/usr/bin/env bash
# dctl installer — run on each node after cloning the repo (or via bootstrap.sh).
#
#   git clone git@github.com:meloncafe/dctl.git ~/.local/share/dctl
#   ~/.local/share/dctl/install.sh
#
# Idempotent: safe to re-run after 'git pull'. Sets up the symlink, the
# registry, and adds the bin dir to PATH in your shell rc.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${DCTL_BIN_DIR:-$HOME/.local/bin}"
CFG_DIR="$HOME/.config/dctl"
REGISTRY="$CFG_DIR/registry.conf"

mkdir -p "$BIN_DIR" "$CFG_DIR"

# --- symlink the command ---
chmod +x "$SRC_DIR/dctl"
ln -sf "$SRC_DIR/dctl" "$BIN_DIR/dctl"
echo "linked: $BIN_DIR/dctl -> $SRC_DIR/dctl"

# --- seed the registry (never overwrite an existing one) ---
if [[ ! -f "$REGISTRY" ]]; then
  cp "$SRC_DIR/registry.example.conf" "$REGISTRY"
  echo "created registry: $REGISTRY  (edit it: dctl edit)"
else
  echo "registry exists, left untouched: $REGISTRY"
fi

# --- ensure BIN_DIR is on PATH via the shell rc ---
add_path_to_rc() {
  local rc
  case "$(basename "${SHELL:-/bin/bash}")" in
    zsh)  rc="$HOME/.zshrc" ;;
    *)    rc="$HOME/.bashrc" ;;
  esac
  local line="export PATH=\"$BIN_DIR:\$PATH\""
  if printf '%s' "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    return 0   # already on PATH for this session
  fi
  if [[ -f "$rc" ]] && grep -qF "$BIN_DIR" "$rc"; then
    echo "PATH entry already present in $rc (restart shell or: source $rc)"
  else
    printf '\n# added by dctl installer\n%s\n' "$line" >> "$rc"
    echo "added $BIN_DIR to PATH in $rc  (restart shell or: source $rc)"
  fi
}
add_path_to_rc

echo "done. try: dctl help"
