#!/usr/bin/env bash
# Shared setup for dctl bats tests.
#
# Sourcing dctl exposes its functions without running main() (thanks to the
# BASH_SOURCE guard). Each test points DCTL_REGISTRY at a temp fixture.

# Resolve the repo root (one level up from test/).
DCTL_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
DCTL_BIN="$DCTL_ROOT/dctl"

# Write a fixture registry and export DCTL_REGISTRY to point at it.
# usage: make_registry <<'EOF' ... EOF   (content on stdin)
make_registry() {
  DCTL_REGISTRY="$(mktemp)"
  export DCTL_REGISTRY
  cat > "$DCTL_REGISTRY"
}

# A standard fixture used by most tests.
load_sample_registry() {
  make_registry <<'EOF'
# comment line
[web]
path  = ~/stacks/web
files = docker-compose.yml

[db]
path     = /srv/db
node     = my-host
files    = base.yml override.yml
post_up  = echo started

[api]
path = /srv/api
EOF
}

teardown() {
  [[ -n "${DCTL_REGISTRY:-}" && -f "${DCTL_REGISTRY:-}" ]] && rm -f "$DCTL_REGISTRY"
  return 0
}
