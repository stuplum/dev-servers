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
dev-servers -t           # live TUI: navigate, multi-select, force-stop
DEV_ROOT=~/Workspace dev-servers   # narrow the search root (default: $HOME)
```

### TUI (`-t`)

A live, auto-refreshing view you can leave running. Pick one or many servers and
force-stop them (the whole process subtree, `SIGTERM` then `SIGKILL`).

```
↑/↓ or j/k   move          space   select / deselect
a            select all    n       clear selection
x or enter   force-stop    r       refresh now
q or esc     quit
```

Pressing `x` stops the selected servers, or the highlighted one if nothing is
selected, after a `[y/N]` confirm. Refresh interval is 2s; override with
`DEV_SERVERS_INTERVAL`. Zero dependencies — pure zsh.

## Install

```
curl -fsSL https://raw.githubusercontent.com/stuplum/dev-servers/main/install.sh | zsh
```

Downloads the script to `~/.local/bin/dev-servers` (make sure that's on your
`PATH`) and keeps `~/dev-servers.sh` working for backwards compatibility.

## Requirements

`zsh`, `lsof`, `git`, and standard BSD/macOS `ps`/`awk`. Built for macOS.

## Roadmap

- Sort/filter controls in the TUI (by repo, by port).
- Optionally show the command line, not just the process name.
