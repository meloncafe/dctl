#!/usr/bin/env bats
# Tests for run_compose remote (ssh) argument serialization.
#
# We stub `ssh` so the assembled remote command string is captured and can be
# asserted on, without any real ssh/docker. The key property: quotes, pipes and
# spaces in arguments must survive as a single argument to the remote shell,
# not split apart (a naive "$*" would break `sh -c "a | b"` at the pipe).

load helper

setup() {
  load_sample_registry
  source "$DCTL_BIN"

  # Stub ssh: print its final argument (the remote command) verbatim.
  ssh() {
    # args: -t <node> <remote-cmd> ; emit just the remote-cmd
    printf '%s\n' "${!#}"
  }

  # Pretend we target a remote node.
  NODE="my-host"
  PATH_="/srv/app"
  FILES=""
}

@test "remote: simple args pass through" {
  run run_compose exec db psql -U postgres
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker compose exec db psql -U postgres"* ]]
  [[ "$output" == *"cd /srv/app"* ]]
}

@test "remote: piped sh -c stays a single argument" {
  run run_compose exec db sh -c "pg_dump | gzip > /tmp/b.gz"
  [ "$status" -eq 0 ]
  # the whole 'pg_dump | gzip > /tmp/b.gz' must remain quoted as one arg,
  # i.e. the pipe must be escaped/quoted, not left bare after 'sh -c'
  [[ "$output" != *"sh -c pg_dump | gzip"* ]]
  # a bare unescaped pipe would appear; ensure it's escaped or quoted
  [[ "$output" == *'sh -c'* ]]
  [[ "$output" == *'pg_dump'* ]]
  [[ "$output" == *'gzip'* ]]
}

@test "remote: spaces in an argument are preserved as one token" {
  run run_compose exec db echo "hello world"
  [ "$status" -eq 0 ]
  # 'hello world' must not become two bare words after echo
  [[ "$output" != *"echo hello world"* ]]
  [[ "$output" == *"hello"* ]]
  [[ "$output" == *"world"* ]]
}

@test "remote: compose files are included" {
  FILES="base.yml override.yml"
  run run_compose up -d
  [ "$status" -eq 0 ]
  [[ "$output" == *"-f base.yml -f override.yml"* ]]
}

@test "remote: path with a space is quoted in cd" {
  PATH_="/srv/my app"
  run run_compose ps
  [ "$status" -eq 0 ]
  # cd target must keep the space as one token (escaped or quoted)
  [[ "$output" != *"cd /srv/my app &&"* ]]
  [[ "$output" == *"my"* ]]
  [[ "$output" == *"app"* ]]
}
