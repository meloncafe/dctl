#!/usr/bin/env bats
# Tests for the version command and update_count() (the quiet update check).

load helper

setup() {
  source "$DCTL_BIN"
}

@test "version prints the version constant" {
  # not a git checkout -> just the version line, no update noise
  self_src_dir() { printf '%s' "/nonexistent-checkout"; }
  run version
  [ "$status" -eq 0 ]
  [[ "$output" == dctl\ * ]]
  [[ "$output" == *"$DCTL_VERSION"* ]]
}

@test "update_count is silent when not a git checkout" {
  self_src_dir() { printf '%s' "/nonexistent-checkout"; }
  run update_count
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "update_count reports commits behind upstream" {
  local work; work="$(mktemp -d)"
  git init -q --bare "$work/bare"
  git clone -q "$work/bare" "$work/up" 2>/dev/null
  git -C "$work/up" config user.email t@t.com
  git -C "$work/up" config user.name t
  printf 'a\n' > "$work/up/f"
  git -C "$work/up" add -A
  git -C "$work/up" commit -qm c1
  git -C "$work/up" branch -M main
  git -C "$work/up" push -q origin main
  git clone -q "$work/bare" "$work/node" 2>/dev/null
  git -C "$work/node" checkout -q main

  # two new upstream commits
  printf 'b\n' >> "$work/up/f"; git -C "$work/up" commit -qam c2
  printf 'c\n' >> "$work/up/f"; git -C "$work/up" commit -qam c3
  git -C "$work/up" push -q origin main

  self_src_dir() { printf '%s' "$work/node"; }
  run update_count
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
  rm -rf "$work"
}

@test "update_count stays silent on an unreachable remote" {
  local work; work="$(mktemp -d)"
  git init -q --bare "$work/bare"
  git clone -q "$work/bare" "$work/node" 2>/dev/null
  git -C "$work/node" config user.email t@t.com
  git -C "$work/node" config user.name t
  printf 'a\n' > "$work/node/f"
  git -C "$work/node" add -A
  git -C "$work/node" commit -qm c1
  git -C "$work/node" branch -M main
  # point origin at an unroutable address
  git -C "$work/node" remote set-url origin https://10.255.255.1/nope.git

  self_src_dir() { printf '%s' "$work/node"; }
  run update_count
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  rm -rf "$work"
}
