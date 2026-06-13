#!/usr/bin/env bats
# Tests for the shell completion logic in completion.bash.

setup() {
  COMP_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  # fixture registry
  DCTL_REGISTRY="$(mktemp)"
  export DCTL_REGISTRY
  cat > "$DCTL_REGISTRY" <<'EOF'
[web]
path = /tmp/x
[database]
path = /tmp/y
[api-server]
path = /tmp/z
EOF
  source "$COMP_ROOT/completion.bash"
}

teardown() {
  [[ -n "${DCTL_REGISTRY:-}" && -f "${DCTL_REGISTRY:-}" ]] && rm -f "$DCTL_REGISTRY"
  return 0
}

@test "service names are read from the registry" {
  run __dctl_services
  [[ "$output" == *"web"* ]]
  [[ "$output" == *"database"* ]]
  [[ "$output" == *"api-server"* ]]
}

@test "no-target commands are recognized" {
  __dctl_no_target_cmd validate
  __dctl_no_target_cmd version
  __dctl_no_target_cmd edit
  ! __dctl_no_target_cmd restart
  ! __dctl_no_target_cmd logs
}

@test "first word completes commands" {
  COMP_WORDS=(dctl re); COMP_CWORD=1
  _dctl_bash
  [[ " ${COMPREPLY[*]} " == *" restart "* ]]
}

@test "target command completes service names" {
  COMP_WORDS=(dctl restart ""); COMP_CWORD=2
  _dctl_bash
  [[ " ${COMPREPLY[*]} " == *" web "* ]]
  [[ " ${COMPREPLY[*]} " == *" database "* ]]
}

@test "partial service name is filtered" {
  COMP_WORDS=(dctl restart a); COMP_CWORD=2
  _dctl_bash
  [[ " ${COMPREPLY[*]} " == *" api-server "* ]]
  [[ " ${COMPREPLY[*]} " != *" web "* ]]
}

@test "flags complete on a leading dash" {
  COMP_WORDS=(dctl --); COMP_CWORD=1
  _dctl_bash
  [[ " ${COMPREPLY[*]} " == *" --all "* ]]
  [[ " ${COMPREPLY[*]} " == *" --dry-run "* ]]
}

@test "no-target command offers no services" {
  COMP_WORDS=(dctl validate ""); COMP_CWORD=2
  _dctl_bash
  [ "${#COMPREPLY[@]}" -eq 0 ]
}
