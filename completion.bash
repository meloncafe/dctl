#!/usr/bin/env bash
# dctl shell completion — bash and zsh.
#
# Sourced by your shell rc (install.sh wires this up). Completes the dctl
# subcommands, global flags, and registered service names.
#
#   bash: source this file (or drop it in a bash-completion dir)
#   zsh:  autoload + bashcompinit, then source this file

# Commands and global flags offered as the first word / as options.
__dctl_commands="up down restart update pull logs ps exec config stats pause unpause prune list ls validate doctor edit version self-update upgrade help"
__dctl_flags="--all --dry-run --no-color --quiet --help --version"

# Read service section names from the registry, honoring DCTL_REGISTRY.
__dctl_services() {
  local reg="${DCTL_REGISTRY:-$HOME/.config/dctl/registry.conf}"
  [[ -f "$reg" ]] || return 0
  # section headers: [name]
  sed -n 's/^[[:space:]]*\[\([^]]*\)\].*/\1/p' "$reg" 2>/dev/null
}

# Commands that don't take a service target (so we don't offer services there).
__dctl_no_target_cmd() {
  case "$1" in
    list|ls|validate|doctor|edit|version|self-update|selfupdate|upgrade|help) return 0 ;;
    *) return 1 ;;
  esac
}

# ---- bash ----
_dctl_bash() {
  local cur
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"

  # the command is the first non-flag word after "dctl"
  local i cmd=""
  for ((i = 1; i < COMP_CWORD; i++)); do
    case "${COMP_WORDS[i]}" in
      -*) continue ;;
      *) cmd="${COMP_WORDS[i]}"; break ;;
    esac
  done

  # leading flag
  if [[ "$cur" == -* ]]; then
    # shellcheck disable=SC2207
    COMPREPLY=($(compgen -W "$__dctl_flags" -- "$cur"))
    return 0
  fi

  # first word: complete commands
  if [[ -z "$cmd" ]]; then
    # shellcheck disable=SC2207
    COMPREPLY=($(compgen -W "$__dctl_commands" -- "$cur"))
    return 0
  fi

  # after a target-taking command: complete service names
  if ! __dctl_no_target_cmd "$cmd"; then
    # shellcheck disable=SC2207
    COMPREPLY=($(compgen -W "$(__dctl_services)" -- "$cur"))
    return 0
  fi
}

# ---- zsh ----
# zsh can use the bash function via bashcompinit; this branch wires it up when
# the file is sourced under zsh.
if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -U +X bashcompinit 2>/dev/null && bashcompinit 2>/dev/null
fi

# Register for both shells (complete is provided by bash-completion / bashcompinit).
if command -v complete >/dev/null 2>&1; then
  complete -F _dctl_bash dctl
fi
