# dev-servers

List the dev servers you have running, biggest memory first. Port- and
language-agnostic: Node/Vite, Storybook, Elixir/Phoenix (`beam`), anything.

```
$ dev-servers
   412MB  :3000,3001  my-app  (node)
    88MB  :6006       my-app/feature-branch  (node)
    64MB  :4000       my-api  (beam)
```

## How it decides what's a "dev server"

Rather than matching a fixed port range, a dev server is any process that:

- **you own** and is **listening on TCP**, and
- whose **working directory is inside a git repo under `$HOME`** (excluding
  `~/Library`).

That catches every repo and git worktree regardless of port or language, while
system daemons, Homebrew services (`/opt`), Docker, and editor/toolbox helpers
fall outside the net and are ignored.

`MEM` is the total RSS summed across the server's whole process subtree, so a
Vite/Storybook parent and its workers are counted together.

## Usage

```
dev-servers              # list running dev servers
DEV_ROOT=~/Workspace dev-servers   # narrow the search root (default: $HOME)
```

## Install

```
curl -fsSL https://raw.githubusercontent.com/stuplum/dev-servers/main/install.sh | zsh
```

Downloads the script to `~/.local/bin/dev-servers` (make sure that's on your
`PATH`) and keeps `~/dev-servers.sh` working for backwards compatibility.

## Requirements

`zsh`, `lsof`, `git`, and standard BSD/macOS `ps`/`awk`. Built for macOS.

## Roadmap

- **Continuous TUI** — a live-refreshing view you can leave running, with
  pick-and-force-stop for one or many servers (kills the whole subtree). The
  data the list already computes (subtree pids per server) is what a stop
  action needs; the open work is the interactive, always-on interface.
