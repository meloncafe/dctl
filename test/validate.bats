#!/usr/bin/env bats
# Tests for validate(): registry sanity checks.

load helper

setup() {
  source "$DCTL_BIN"
  VWORK="$(mktemp -d)"
  mkdir -p "$VWORK/web"
  printf 'services:\n' > "$VWORK/web/docker-compose.yml"
}

teardown() {
  [[ -n "${DCTL_REGISTRY:-}" && -f "${DCTL_REGISTRY:-}" ]] && rm -f "$DCTL_REGISTRY"
  [[ -n "${VWORK:-}" && -d "${VWORK:-}" ]] && rm -rf "$VWORK"
  return 0
}

@test "validate passes for a correct local service" {
  make_registry <<EOF
[web]
path  = $VWORK/web
files = docker-compose.yml
EOF
  source "$DCTL_BIN"
  run validate
  [ "$status" -eq 0 ]
  [[ "$output" == *"[web] ok"* ]]
}

@test "validate flags a missing path" {
  make_registry <<EOF
[ghost]
path = $VWORK/nope
files = docker-compose.yml
EOF
  source "$DCTL_BIN"
  run validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"path does not exist"* ]]
}

@test "validate flags a missing compose file" {
  mkdir -p "$VWORK/api"
  make_registry <<EOF
[api]
path  = $VWORK/api
files = docker-compose.yml
EOF
  source "$DCTL_BIN"
  run validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"compose file not found"* ]]
}

@test "validate flags a service with no path" {
  make_registry <<'EOF'
[broken]
node = somewhere
EOF
  source "$DCTL_BIN"
  run validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required 'path'"* ]]
}

@test "validate skips path/file checks for remote services" {
  make_registry <<'EOF'
[remote]
node = my-host
path = /srv/whatever
files = a.yml
EOF
  source "$DCTL_BIN"
  run validate
  # remote service alone has no local problems -> passes
  [ "$status" -eq 0 ]
  [[ "$output" == *"remote on 'my-host'"* ]]
}

@test "validate counts multiple problems and fails" {
  make_registry <<EOF
[web]
path  = $VWORK/web
files = docker-compose.yml
[ghost]
path  = $VWORK/nope
files = docker-compose.yml
[broken]
node = x
EOF
  source "$DCTL_BIN"
  run validate
  [ "$status" -ne 0 ]
  [[ "$output" == *"problem(s)"* ]]
}
