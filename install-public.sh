#!/usr/bin/env bash
# dctl bootstrap — one-line installer for a PUBLIC repo (no gh CLI needed).
#
#   curl -fsSL https://raw.githubusercontent.com/<owner>/dctl/main/install-public.sh | bash
#
# Override the source repo/branch if you forked:
#   DCTL_REPO=youruser/dctl DCTL_REF=main curl -fsSL .../install-public.sh | bash
#
# Clones (or fast-forwards) the repo over https, then runs install.sh.
# For a PRIVATE repo, use bootstrap.sh via the gh CLI instead.

set -euo pipefail

REPO="${DCTL_REPO:-meloncafe/dctl}"
REF="${DCTL_REF:-main}"
DEST="${DCTL_SRC_DIR:-$HOME/.local/share/dctl}"

command -v git >/dev/null 2>&1 || {
  echo "dctl: 'git' not found. Install git first." >&2
  exit 1
}

if [[ -d "$DEST/.git" ]]; then
  echo "dctl: updating existing checkout at $DEST"
  # Ignore file-mode (exec bit) changes so install.sh's chmod never blocks pull.
  git -C "$DEST" config core.fileMode false
  git -C "$DEST" pull --ff-only
else
  echo "dctl: cloning $REPO -> $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --branch "$REF" "https://github.com/$REPO.git" "$DEST"
  git -C "$DEST" config core.fileMode false
fi

exec bash "$DEST/install.sh"
