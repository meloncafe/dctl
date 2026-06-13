# Changelog

All notable changes to dctl are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/meloncafe/dctl/releases/tag/v0.1.0
