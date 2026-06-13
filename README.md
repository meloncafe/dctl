# dctl

[![CI](https://github.com/meloncafe/dctl/actions/workflows/ci.yml/badge.svg)](https://github.com/meloncafe/dctl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Unified `docker compose` controller. Resolve services **by name** from a central
registry, drive them from the **current directory** or **by name**, and reach
**remote nodes over ssh** — with **per-service hooks**, **multi compose-file**
support, **multi-service** commands, a **dry-run** preview, and a registry
**validate** check.

Replaces the per-directory `logs.sh` / `restart.sh` sprawl with one command.

```bash
dctl restart web          # pull → down → up → tail logs, for the "web" service
dctl logs db              # follow logs by service name, from anywhere
dctl restart worker       # ...even if "worker" runs on another host over ssh
dctl up web db api        # ...or several services in turn
dctl restart --all -n     # dry-run a whole-stack restart without touching anything
```

## ⚠️ Security — read before you use hooks

dctl runs `docker compose` for you, and optionally runs **hooks**: shell command
strings you store in the registry. Understand the trust model:

- **Hook values are executed verbatim** — locally via `eval`, or on the remote
  host over ssh. They are arbitrary shell commands. Treat your
  `registry.conf` like a shell script you are about to run as yourself.
- **Only put commands you trust in hooks.** Never paste a registry file from an
  untrusted source, and don't point `DCTL_REGISTRY` at a file you didn't write.
- **Remote control runs commands over ssh** on whatever host a service's `node`
  points to, using your ssh credentials. A wrong `node` value runs your command
  on the wrong machine.
- The install uses `curl | bash` / `gh api | bash`. If you prefer not to pipe to
  a shell, use the **manual install** below and read the scripts first.

dctl does not handle secrets, store credentials, or phone home. It only wraps
`docker compose` and ssh.

> Tip: use `dctl <cmd> --dry-run` to see exactly what would run (including hooks
> and the target host) before executing anything.

## Install

### One-liner (public repo, no extra tooling)

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/dctl/main/install-public.sh | bash
```

Replace `<owner>` with the repo owner (or set `DCTL_REPO=<owner>/dctl`). This
clones (or fast-forwards) the repo to `~/.local/share/dctl` over https and runs
`install.sh`, which symlinks `dctl`, seeds the registry, wires up shell
completion, and adds `~/.local/bin` to your PATH. Forked?
`DCTL_REPO=youruser/dctl DCTL_REF=main curl -fsSL ... | bash`.

### Private repo (via the gh CLI)

```bash
gh api repos/<owner>/dctl/contents/bootstrap.sh \
  -H "Accept: application/vnd.github.raw" | bash
```

### Manual (read the scripts first)

```bash
git clone https://github.com/<owner>/dctl.git ~/.local/share/dctl
~/.local/share/dctl/install.sh
```

### Update

```bash
dctl version              # show the version, and whether an update is available
dctl self-update          # pull latest + re-run install.sh
```

`self-update` only updates the dctl scripts (it `git pull`s the checkout in
`~/.local/share/dctl`). Your registry at `~/.config/dctl/registry.conf` lives
outside the repo and is never touched, overwritten, or committed. It prints a
short progress summary (commits applied, the new version) rather than raw git
output. If a local change blocks the fast-forward, dctl explains how to recover
instead of failing with a raw git error.

`version` and `self-update` do a quick check for upstream commits. If the
network is unreachable (offline, an intranet with no route to GitHub), the check
is skipped silently — it never hangs or errors. Everyday commands do no network
I/O.

## Registry

Lives at `~/.config/dctl/registry.conf` (override with `DCTL_REGISTRY`). It is
**not** committed — each node keeps its own, since services differ per node.

```ini
[web]
path    = ~/stacks/web
files   = docker-compose.yml

[api]
path    = ~/stacks/api
files   = docker-compose.yml docker-compose.prod.yml

[worker]
node    = my-other-host           # ssh Host alias from ~/.ssh/config
path    = /home/user/worker
files   = docker-compose.yml
```

| field | required | meaning |
|-------|----------|---------|
| `path` | yes | compose project directory (`~` ok for local) |
| `node` | no | ssh host alias; omit = local node |
| `files` | no | space-separated compose files; omit = compose default |
| `pre_up` / `post_up` | no | shell command around `up` (executed verbatim — see Security) |
| `pre_down` / `post_down` | no | shell command around `down` (executed verbatim — see Security) |

Hooks run in the service's context — locally for local services, over ssh for
remote ones.

Run `dctl validate` to check the registry before relying on it (see below).

## Usage

```bash
dctl restart                 # current directory
dctl logs web                # by service name
dctl exec db psql -U postgres
dctl restart worker          # remote, if worker.node is set
TAIL=100 dctl logs api
```

### Several services at once

Pass more than one registered name, or `--all`, to act on each in turn. They run
sequentially; if one fails the rest still run, and dctl prints a summary and
exits non-zero when anything failed. `exec`, `logs`, and `config` stay
single-service.

```bash
dctl up web db api           # bring up three services in order
dctl pull --all              # pull images for every registered service
dctl restart --all           # restart the whole stack (no log-follow in batch mode)
```

### Dry run

`--dry-run` (or `-n`) prints what would happen — the compose command, target
host, and any hooks — without executing anything. Combine it with multi-service
to preview a whole batch.

```bash
dctl restart web -n          # show the down → pull → up → hooks plan, run nothing
dctl up --all --dry-run      # preview the entire stack coming up
```

### Commands

| command | action |
|---------|--------|
| `up` | `pre_up` → `up -d` → `post_up`  (rolls back partial state on failure) |
| `down` | `pre_down` → `down` → `post_down` |
| `restart` | `pre_down` → down --remove-orphans → `pre_up` → pull → up → `post_up` → logs |
| `update` | `pre_up` → pull → up -d → `post_up`  (no downtime; rolls back on failure) |
| `pull` | pull images only |
| `logs` | follow logs (`TAIL=N`, default 20) |
| `ps` / `stats` / `config` | status / live usage / merged config |
| `exec` | exec into a service container |
| `pause` / `unpause` | pause / resume |
| `prune` | `docker system prune -f` (respects target node) |
| `list` / `edit` | list services / edit registry |
| `validate` | check the registry (alias `doctor`) |
| `version` | print the version (and check for an update if reachable) |
| `self-update` | pull the latest dctl and re-run install.sh |

### Global flags

| flag | effect |
|------|--------|
| `--all` | target every registered service |
| `--dry-run`, `-n` | print what would run without executing |
| `--no-color` | disable colored output (also respects `NO_COLOR`) |
| `--quiet`, `-q` | suppress info/ok/warn messages (errors still shown) |

Flags may appear anywhere on the command line.

## Shell completion

`install.sh` sources `completion.bash` from your shell rc (`~/.bashrc` or
`~/.zshrc`), so after the next install — or `self-update`, which re-runs
`install.sh` — and a new shell, `<Tab>` completes commands and service names:

```bash
dctl re<Tab>             # -> restart
dctl restart <Tab>       # -> web  db  api  worker   (registered service names)
dctl --<Tab>             # -> --all  --dry-run  --no-color  --quiet
```

Service names come from your registry, so they stay in sync as you edit it.

## Validate the registry

`dctl validate` (alias `dctl doctor`) sanity-checks every service:

- each has a `path`,
- local `path`s exist and the listed compose `files` are present,
- a `node` looks defined as a `Host` in `~/.ssh/config`.

Remote `path`/`files` aren't checked (that would need an ssh round-trip). It
exits non-zero if it finds any problem, so it fits in CI or a pre-flight step.

```bash
$ dctl validate
dctl: [web] ok
dctl: [api] compose file not found: /home/user/stacks/api/docker-compose.prod.yml
dctl: [worker] remote on 'my-other-host' (path/files not checked)
dctl: validate: 1 problem(s) across 3 service(s)
```

## Remote nodes

Remote control uses your existing `~/.ssh/config` host aliases — no extra
credential handling. Point each `Host` at its address (Tailscale name/IP works
well) and `dctl restart <service>` runs across machines. Arguments are quoted so
a payload like `dctl exec db sh -c "pg_dump | gzip"` reaches the remote shell
intact. See the Security note about what runs where.

## Notes

- `restart` has downtime (down→up). Use `update` for image refresh without `down`.
- A failed `up` is rolled back (`down --remove-orphans`) and exits non-zero, so
  you never end up with a silently half-started stack.
- In multi-service mode `restart` skips the trailing log-follow (following the
  first service's logs would block the rest); single-service `restart` still
  tails logs at the end.
- Services needing manual steps after start (e.g. a secrets store that must be
  unsealed) can put a reminder or command in `post_up`.

## Development

The script is pure bash with a small bats test suite; CI runs shellcheck and the
tests on every push.

```bash
bats test/                   # run the suite
shellcheck -s bash dctl      # lint (dctl has no extension, so -s bash)
```

## License

MIT — see [LICENSE](LICENSE).
