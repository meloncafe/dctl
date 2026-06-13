# Changelog

All notable changes to dctl are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-06-13

Convenience pass. No breaking changes.

### Added

- **`validate`** (alias `doctor`) — sanity-checks the registry: every service
  has a `path`, local paths and listed compose files exist, and `node` aliases
  look defined in `~/.ssh/config`. Remote path/file existence is not checked
  (would need an ssh round-trip). Exits non-zero if any problem is found.
- **Color output and global flags** — `ok` / `warn` / `err` messages are
  colored; color auto-disables when `NO_COLOR` is set, `--no-color` is passed,
  or stderr is not a terminal. `--quiet` / `-q` silences info/ok/warn (errors
  are always shown). Both flags may appear anywhere on the command line.

### Changed

- **`edit`** now tries `$EDITOR`, `$VISUAL`, `nano`, `vi`, `vim` in order, and
  if none is available prints the registry path instead of failing silently.
- **`self-update`** explains a failed fast-forward (local commits/changes) and
  how to recover, instead of surfacing a raw git error.

## [0.2.0] - 2026-06-13

Reliability and testability pass. No breaking changes.

### Fixed

- **Remote argument quoting** — `run_compose`'s ssh path built the command with
  a bare `"$*"`, so an argument like `sh -c "pg_dump | gzip"` split at the pipe
  on the remote shell (the pipe became a separate remote command — a data-loss
  risk), and spaces within an argument became separate words. Arguments and the
  remote `cd` target are now serialized with `printf '%q'`. Local execution was
  already correct and is unchanged.
- Removed a no-op `TAIL=...` env assignment on the `restart` logs line
  (shellcheck SC2097/SC2098); the trailing `${TAIL:-20}` already applied the
  default, so behavior is unchanged.

### Added

- **Test suite (bats)** — unit tests for the registry parser (`get_field`,
  `list_services`), target resolution (`resolve`), compose-file assembly, and
  remote ssh argument serialization. 22 tests.
- **CI** — GitHub Actions runs shellcheck and the bats suite on every push and
  pull request.

### Changed

- **Internal refactor** — all logic moved into functions; `main()` runs only
  when the script is executed directly (sourcing exposes functions for tests
  without side effects). No change to the command-line behavior.

## [0.1.0] - 2026-06-13

First public release.

### Added

- **Service-name resolution** via a central registry (`~/.config/dctl/registry.conf`).
  Drive a stack from anywhere by name (`dctl restart web`) instead of `cd`-ing
  into each compose directory.
- **Current-directory mode** — omit the target to act on the compose project in
  the working directory, replacing per-directory `logs.sh` / `restart.sh`.
- **Remote control over ssh** — set `node = <ssh-host>` on a service to run its
  compose commands on another host using your existing `~/.ssh/config` aliases.
- **Per-service hooks** — `pre_up` / `post_up` / `pre_down` / `post_down` shell
  commands run in the service's context (locally or over ssh).
- **Multiple compose files** — `files = a.yml b.yml` assembles `-f a.yml -f b.yml`.
- **Commands**: `up`, `down`, `restart`, `update` (no-downtime refresh), `pull`,
  `logs` (`TAIL=N`), `ps`, `exec`, `config`, `stats`, `pause` / `unpause`,
  `prune`, `list`, `edit`, `self-update`, `help`.
- **`self-update`** — pulls the latest dctl and re-runs `install.sh`. Updates
  only the scripts; the per-node registry is never touched.
- **Installers** — gh-free public one-liner (`install-public.sh`, https clone),
  a `gh`-based one-liner for private repos (`bootstrap.sh`), and manual install.
  All set up the symlink, seed the registry, and add `~/.local/bin` to PATH.

### Reliability

- **Failed `up` rolls back** — a partial `up` (port in use, pull error) is torn
  down with `--remove-orphans` and exits non-zero, so a stack never ends up
  silently half-started. `restart` also clears orphans before bringing things up.

### Notes

- Hook values are executed verbatim (locally via the shell, or over ssh). Treat
  the registry like a script you run as yourself — see the Security section in
  the README.

[Unreleased]: https://github.com/meloncafe/dctl/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/meloncafe/dctl/releases/tag/v0.3.0
[0.2.0]: https://github.com/meloncafe/dctl/releases/tag/v0.2.0
[0.1.0]: https://github.com/meloncafe/dctl/releases/tag/v0.1.0
