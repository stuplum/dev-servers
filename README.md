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

Select the servers you want with `space` (or `a` for all), then `x` to
force-stop them after a `[y/N]` confirm — `x` only ever touches the explicit
selection. The list scrolls when it overflows and the legend stays pinned to
the bottom. Refresh interval is 2s; override with `DEV_SERVERS_INTERVAL`. Zero
dependencies — pure zsh.

## Install

```
curl -fsSL https://raw.githubusercontent.com/stuplum/dev-servers/main/install.sh | zsh
```

Downloads the script to `~/.local/bin/dev-servers` (make sure that's on your
`PATH`) and keeps `~/dev-servers.sh` working for backwards compatibility.

## Wave Terminal widget

[Wave Terminal](https://waveterm.dev) can launch the TUI from its widget bar.
Add this to `~/.config/waveterm/widgets.json` (merge it in if the file already
exists), then click the **dev servers** button:

```json
{
  "dev-servers": {
    "icon": "server",
    "label": "dev servers",
    "color": "#3fb950",
    "display:order": 5,
    "blockdef": {
      "meta": {
        "view": "term",
        "controller": "cmd",
        "cmd": "zsh -ic 'dev-servers -t'",
        "cmd:clearonstart": true
      }
    }
  }
}
```

The `zsh -ic '…'` wrapper runs it through an interactive shell so `dev-servers`
resolves on your `PATH` (Wave launches widget commands with a minimal GUI
`PATH`). If your shell isn't zsh, swap it, or use the absolute install path
(`~/.local/bin/dev-servers -t`). The snippet also lives in
[`wave-widget.json`](wave-widget.json).

## Requirements

`zsh`, `lsof`, `git`, and standard BSD/macOS `ps`/`awk`. Built for macOS.

## Roadmap

- Sort/filter controls in the TUI (by repo, by port).
- Optionally show the command line, not just the process name.
