# dctl

Unified `docker compose` controller. Resolve services **by name** from a central
registry, drive them from the **current directory** or **by name**, and reach
**remote nodes over ssh** — with **per-service hooks** and **multi compose-file**
support.

Replaces the per-directory `logs.sh` / `restart.sh` sprawl with one command.

```bash
dctl restart web          # pull → down → up → tail logs, for the "web" service
dctl logs db              # follow logs by service name, from anywhere
dctl restart worker       # ...even if "worker" runs on another host over ssh
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

## Install

### One-liner (public repo, no extra tooling)

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/dctl/main/install-public.sh | bash
```

Replace `<owner>` with the repo owner (or set `DCTL_REPO=<owner>/dctl`). This
clones (or fast-forwards) the repo to `~/.local/share/dctl` over https and runs
`install.sh`, which symlinks `dctl`, seeds the registry, and adds `~/.local/bin`
to your PATH. Forked? `DCTL_REPO=youruser/dctl DCTL_REF=main curl -fsSL ... | bash`.

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
dctl self-update          # pull latest + re-run install.sh
```

`self-update` only updates the dctl scripts (it `git pull`s the checkout in
`~/.local/share/dctl`). Your registry at `~/.config/dctl/registry.conf` lives
outside the repo and is never touched, overwritten, or committed.

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

## Usage

```bash
dctl restart                 # current directory
dctl logs web                # by service name
dctl exec db psql -U postgres
dctl restart worker          # remote, if worker.node is set
TAIL=100 dctl logs api
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
| `self-update` | pull the latest dctl and re-run install.sh |

## Remote nodes

Remote control uses your existing `~/.ssh/config` host aliases — no extra
credential handling. Point each `Host` at its address (Tailscale name/IP works
well) and `dctl restart <service>` runs across machines. See the Security note
about what runs where.

## Notes

- `restart` has downtime (down→up). Use `update` for image refresh without `down`.
- A failed `up` is rolled back (`down --remove-orphans`) and exits non-zero, so
  you never end up with a silently half-started stack.
- Services needing manual steps after start (e.g. a secrets store that must be
  unsealed) can put a reminder or command in `post_up`.
- Argument parsing favors the common cases; unusual `exec` payloads may need
  `--` separation.

## License

MIT — see [LICENSE](LICENSE).
