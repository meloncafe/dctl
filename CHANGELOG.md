# Changelog

All notable changes to dctl are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.1] - 2026-06-13

Patch. No breaking changes.

### Changed

- **`self-update` output is now a short progress summary** instead of git's raw
  fetch/merge log. It prints `checking for updates…`, `applying N new
  commit(s)…`, and `updated to dctl <version>` — no object counting, no
  `From github.com…` line, no fast-forward diffstat, and none of `install.sh`'s
  routine output. The installer's output is captured and shown only if it
  fails. `already up to date` stays a one-liner with the version.

## [0.5.0] - 2026-06-13

Feature pass. No breaking changes.

### Added

- **`version` command** (aliases `--version` / `-v`) — prints the dctl version,
  which is now also shown in the `help` header. The version is a constant in
  the script, so it prints instantly with no git or network access.
- **Quiet update check** — `version` and `self-update` do a short-timeout
  `git fetch` and report how many commits the upstream is ahead. It runs only
  for those two commands, so everyday commands (`logs`, `restart`, …) do no
  network I/O. The check stays completely silent on any failure — offline, an
  intranet with no route to GitHub, no git, or not a checkout — so it never
  hangs or adds noise.
- **Shell completion** (`completion.bash`, bash + zsh) — completes subcommands,
  global flags, and registered service names (`dctl <Tab>`, `dctl restart
  <Tab>`). `install.sh` now sources it from your shell rc (idempotent), so it
  activates after the next `install.sh` run (e.g. via `self-update`) and a new
  shell.

## [0.4.1] - 2026-06-13

Patch. No breaking changes.

### Fixed

- **`self-update` now diagnoses why a fast-forward can't happen.** It used to
  run `git pull --ff-only` and, on failure, always blamed local commits or
  changes — misleading after an upstream force-push (e.g. a squash), which left
  a checkout stuck on a raw "Not possible to fast-forward" git error. It now
  fetches and classifies the state, then prints the right recovery:
  up-to-date (no-op), behind (fast-forwards), uncommitted changes
  (`git checkout -- .`), local commits ahead (`git reset --hard <upstream>`),
  or diverged history from a force-push (`git reset --hard <upstream>`, noting
  the registry in `~/.config/dctl` is untouched).

## [0.4.0] - 2026-06-13

Feature expansion. No breaking changes.

### Added

- **Multi-service commands** — pass several service names
  (`dctl restart web db api`) or `--all` to act on every registered service.
  Services run in turn; one failure neither aborts the batch nor leaks state
  (each runs in an isolated subshell), and a summary reports any failures with
  a non-zero exit. `exec`, `logs`, and `config` remain single-service.
- **`--dry-run` / `-n`** — print the compose plan and hooks (location, files,
  arguments) without executing anything, `prune` included. Combines with
  multi-service to preview a whole batch.

### Changed

- Command execution was extracted into `dispatch_command()` so it can run
  per-service. Single-service and current-directory behavior is unchanged.
- Multi-service `restart` skips the trailing `logs -f` (following the first
  service's logs would block the rest); single-service `restart` still follows.

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

[Unreleased]: https://github.com/meloncafe/dctl/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/meloncafe/dctl/releases/tag/v0.5.1
[0.5.0]: https://github.com/meloncafe/dctl/releases/tag/v0.5.0
[0.4.1]: https://github.com/meloncafe/dctl/releases/tag/v0.4.1
[0.4.0]: https://github.com/meloncafe/dctl/releases/tag/v0.4.0
[0.3.0]: https://github.com/meloncafe/dctl/releases/tag/v0.3.0
[0.2.0]: https://github.com/meloncafe/dctl/releases/tag/v0.2.0
[0.1.0]: https://github.com/meloncafe/dctl/releases/tag/v0.1.0
