#!/usr/bin/env bats
# Tests for the INI registry parser: get_field and list_services.

load helper

setup() {
  load_sample_registry
  source "$DCTL_BIN"
}

@test "list_services returns all section names in order" {
  run list_services
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "web" ]
  [ "${lines[1]}" = "db" ]
  [ "${lines[2]}" = "api" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "get_field reads a simple value" {
  run get_field web path
  [ "$status" -eq 0 ]
  [ "$output" = "~/stacks/web" ]
}

@test "get_field reads node" {
  run get_field db node
  [ "$output" = "my-host" ]
}

@test "get_field reads a hook value with spaces" {
  run get_field db post_up
  [ "$output" = "echo started" ]
}

@test "get_field returns empty for a field absent in that section" {
  run get_field web node
  [ "$output" = "" ]
}

@test "get_field reads multi-file files field verbatim" {
  run get_field db files
  [ "$output" = "base.yml override.yml" ]
}

@test "get_field does not bleed fields across sections" {
  # 'api' has no files; must not pick up db's files
  run get_field api files
  [ "$output" = "" ]
}

@test "get_field strips inline comments" {
  make_registry <<'EOF'
[svc]
path = /srv/x   # trailing comment
EOF
  source "$DCTL_BIN"
  run get_field svc path
  [ "$output" = "/srv/x" ]
}

@test "list_services ignores comments and blank lines" {
  make_registry <<'EOF'

# just a comment

[only]
path = /x
EOF
  source "$DCTL_BIN"
  run list_services
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "only" ]
}
