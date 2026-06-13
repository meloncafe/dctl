#!/usr/bin/env bats
# Tests for resolve() (target -> NODE/PATH_/FILES/SVC) and compose_fargs().

load helper

setup() {
  load_sample_registry
  source "$DCTL_BIN"
}

@test "compose_fargs is empty for no files" {
  run compose_fargs ""
  [ "$output" = "" ]
}

@test "compose_fargs builds a single -f" {
  # output has a leading space (harmless when word-split into docker compose);
  # capture directly rather than via `run`, which trims surrounding whitespace.
  result="$(compose_fargs "docker-compose.yml")"
  [ "$result" = " -f docker-compose.yml" ]
}

@test "compose_fargs builds multiple -f flags" {
  result="$(compose_fargs "a.yml b.yml")"
  [ "$result" = " -f a.yml -f b.yml" ]
}

@test "resolve with empty target uses current directory" {
  resolve ""
  [ "$NODE" = "" ]
  [ "$PATH_" = "$PWD" ]
  [ "$FILES" = "" ]
  [ "$SVC" = "" ]
}

@test "resolve a local service expands ~ in path" {
  resolve web
  [ "$SVC" = "web" ]
  [ "$NODE" = "" ]
  [ "$PATH_" = "$HOME/stacks/web" ]
  [ "$FILES" = "docker-compose.yml" ]
}

@test "resolve a remote service keeps path unexpanded and sets node" {
  resolve db
  [ "$SVC" = "db" ]
  [ "$NODE" = "my-host" ]
  [ "$PATH_" = "/srv/db" ]
  [ "$FILES" = "base.yml override.yml" ]
}

@test "resolve an unknown service fails" {
  run resolve nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown service: nope"* ]]
}

@test "resolve a service missing path fails clearly" {
  make_registry <<'EOF'
[broken]
node = somewhere
EOF
  source "$DCTL_BIN"
  run resolve broken
  [ "$status" -ne 0 ]
  [[ "$output" == *"has no 'path'"* ]]
}
