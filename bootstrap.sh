#!/usr/bin/env bash
# dctl bootstrap — one-line installer via the gh CLI.
#
# For a private repo (or to pin a fork), set DCTL_REPO:
#
#   DCTL_REPO=youruser/dctl \
#   gh api repos/youruser/dctl/contents/bootstrap.sh \
#     -H "Accept: application/vnd.github.raw" | bash
#
# Clones (or fast-forwards) the repo, then runs install.sh.

set -euo pipefail

REPO="${DCTL_REPO:-meloncafe/dctl}"
DEST="${DCTL_SRC_DIR:-$HOME/.local/share/dctl}"

command -v gh >/dev/null 2>&1 || {
  echo "dctl: 'gh' CLI not found. Install it first: https://cli.github.com" >&2
  exit 1
}
gh auth status >/dev/null 2>&1 || {
  echo "dctl: gh is not authenticated. Run: gh auth login" >&2
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
  gh repo clone "$REPO" "$DEST"
  git -C "$DEST" config core.fileMode false
fi

exec bash "$DEST/install.sh"
