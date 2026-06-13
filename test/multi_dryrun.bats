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

@test "multi-service dry-run iterates every named service" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" pull web db api --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== web ==="* ]]
  [[ "$output" == *"=== db ==="* ]]
  [[ "$output" == *"=== api ==="* ]]
}

@test "--all selects every registered service" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" pull --all --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== web ==="* ]]
  [[ "$output" == *"=== db ==="* ]]
  [[ "$output" == *"=== api ==="* ]]
}

@test "exec rejects multiple services" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" exec web db
  [ "$status" -ne 0 ]
  [[ "$output" == *"single service only"* ]]
}

@test "multi-service summary reports failures and exits non-zero" {
  # stub docker to fail for one service via a fake PATH
  local bindir; bindir="$(mktemp -d)"
  cat > "$bindir/docker" <<'SH'
#!/usr/bin/env bash
# fail when operating in the fail-svc project dir
if [[ "$PWD" == *fail-svc* ]]; then exit 1; fi
exit 0
SH
  chmod +x "$bindir/docker"
  mkdir -p /tmp/ok-svc /tmp/fail-svc
  make_registry <<'EOF'
[ok]
path = /tmp/ok-svc
[bad]
path = /tmp/fail-svc
EOF
  run env PATH="$bindir:$PATH" DCTL_REGISTRY="$DCTL_REGISTRY" bash "$DCTL" pull ok bad
  [ "$status" -ne 0 ]
  [[ "$output" == *"failed: bad"* ]]
  rm -rf "$bindir" /tmp/ok-svc /tmp/fail-svc
}

# --- TAIL validation (B4) -------------------------------------------------

@test "non-numeric TAIL is rejected with a clear message" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" TAIL=abc bash "$DCTL" logs web --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"TAIL must be a non-negative integer"* ]]
}

@test "numeric TAIL is accepted" {
  run env DCTL_REGISTRY="$DCTL_REGISTRY" TAIL=50 bash "$DCTL" logs web --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
}
