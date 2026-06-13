#!/usr/bin/env bats
# Tests for multi-service dispatch (B5) and dry-run (B7).
#
# docker/ssh are stubbed so nothing real runs. We mostly drive these through
# main() via the executable, asserting on the emitted plan/summary.

load helper

setup() {
  load_sample_registry
  DCTL="$DCTL_BIN"
}

# --- dry-run (B7) ---------------------------------------------------------

@test "dry-run prints the compose plan without executing" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" up web --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"docker compose"* ]]
  [[ "$output" == *"up -d"* ]]
}

@test "dry-run shows hooks too" {
  # db has post_up in the sample registry
  make_registry <<'EOF'
[svc]
path = /tmp
post_up = echo hi
EOF
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" up svc --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] hook post_up"* ]]
  [[ "$output" == *"echo hi"* ]]
}

@test "dry-run short flag -n works" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" pull web -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
}

# --- multi-service (B5) ---------------------------------------------------

@test "multiple services run in turn with a summary" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" up web api --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== web ==="* ]]
  [[ "$output" == *"=== api ==="* ]]
  [[ "$output" == *"all 2 service(s) done"* ]]
}

@test "--all targets every registered service" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" pull --all --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== web ==="* ]]
  [[ "$output" == *"=== db ==="* ]]
  [[ "$output" == *"=== api ==="* ]]
  [[ "$output" == *"all 3 service(s) done"* ]]
}

@test "multi-service restart omits the trailing logs -f" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" restart web api --dry-run
  [ "$status" -eq 0 ]
  # single restart would end with 'logs --tail .. -f'; multi must not
  [[ "$output" != *"logs --tail"* ]]
}

@test "single restart keeps the trailing logs -f" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" restart web --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"logs --tail"* ]]
}

@test "exec refuses multiple services" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" exec web db
  [ "$status" -ne 0 ]
  [[ "$output" == *"single service only"* ]]
}

@test "logs refuses multiple services" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" logs web db
  [ "$status" -ne 0 ]
  [[ "$output" == *"single service only"* ]]
}

@test "one failure doesn't stop the batch; summary reports it" {
  # stub docker on PATH: fail only when running from a path containing /fail
  local bindir; bindir="$(mktemp -d)"
  cat > "$bindir/docker" <<'EOF'
#!/usr/bin/env bash
[[ "$PWD" == *"/fail"* ]] && exit 1
exit 0
EOF
  chmod +x "$bindir/docker"
  mkdir -p /tmp/ok-svc /tmp/fail-svc
  make_registry <<'EOF'
[good]
path = /tmp/ok-svc
[bad]
path = /tmp/fail-svc
EOF
  run env PATH="$bindir:$PATH" DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" up good bad
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed: bad"* ]]
  rm -rf "$bindir" /tmp/ok-svc /tmp/fail-svc
}
