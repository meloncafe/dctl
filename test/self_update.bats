#!/usr/bin/env bats
# Tests for self_update()'s diagnosis of why a fast-forward can't happen.
#
# We build a throwaway origin + checkout, override self_src_dir() to point at
# the checkout, and assert on the guidance self_update prints for each state:
# up-to-date, clean fast-forward, uncommitted changes, local commits (ahead),
# and diverged history (an upstream force-push).

load helper

setup() {
  source "$DCTL_BIN"

  WORK="$(mktemp -d)"
  git init -q --bare "$WORK/bare"
  git clone -q "$WORK/bare" "$WORK/up" 2>/dev/null
  git -C "$WORK/up" config user.email t@t.com
  git -C "$WORK/up" config user.name t
  cp "$DCTL_BIN" "$WORK/up/dctl"
  printf '#!/usr/bin/env bash\n:\n' > "$WORK/up/install.sh"
  git -C "$WORK/up" add -A
  git -C "$WORK/up" commit -qm c1
  git -C "$WORK/up" branch -M main
  git -C "$WORK/up" push -q origin main

  git clone -q "$WORK/bare" "$WORK/node" 2>/dev/null
  git -C "$WORK/node" checkout -q main
  git -C "$WORK/node" config user.email t@t.com
  git -C "$WORK/node" config user.name t

  NODE_DIR="$WORK/node"
  # point self_update at the node checkout
  eval "self_src_dir() { printf '%s' '$NODE_DIR'; }"
}

teardown() {
  [[ -n "${WORK:-}" && -d "${WORK:-}" ]] && rm -rf "$WORK"
  return 0
}

# push a new upstream commit so the node falls behind
_advance_upstream() {
  printf '# change\n' >> "$WORK/up/dctl"
  git -C "$WORK/up" commit -qam c2
  git -C "$WORK/up" push -q origin main
}

@test "self_update reports already up to date" {
  run self_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
}

@test "self_update fast-forwards when behind" {
  _advance_upstream
  run self_update
  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* ]]
  # node should now match upstream
  [ "$(git -C "$NODE_DIR" rev-parse HEAD)" = "$(git -C "$NODE_DIR" rev-parse origin/main)" ]
}

@test "self_update flags uncommitted changes" {
  _advance_upstream
  printf 'local edit\n' >> "$NODE_DIR/dctl"
  run self_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"uncommitted changes"* ]]
}

@test "self_update flags local commits (ahead)" {
  printf '# local\n' >> "$NODE_DIR/dctl"
  git -C "$NODE_DIR" commit -qam "local change"
  run self_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"local commits"* ]]
  [[ "$output" == *"reset --hard"* ]]
}

@test "self_update detects diverged history (force-push) and suggests reset" {
  git -C "$WORK/up" checkout -q --orphan nr
  git -C "$WORK/up" add -A
  git -C "$WORK/up" commit -qm squashed
  git -C "$WORK/up" push -qf origin nr:main
  run self_update
  [ "$status" -ne 0 ]
  [[ "$output" == *"diverged"* ]]
  [[ "$output" == *"reset --hard origin/main"* ]]
  [[ "$output" == *"registry"* ]]
}
