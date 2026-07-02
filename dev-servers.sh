#!/usr/bin/env zsh
# Dev servers currently listening, biggest memory first:
#     MEM  :PORTS  repo[/worktree]  (cmd)
# MEM = total RSS summed across the server's whole process subtree.
#
# Generic: a "dev server" is any process you own that is listening on TCP and
# whose working directory sits inside a git repo under $HOME (excluding
# ~/Library). Port- and language-agnostic, so it catches Node/Vite dev servers,
# Storybook (6006), Elixir/Phoenix (beam, 4000), and anything in any repo or
# worktree. System daemons, Homebrew services (/opt), Docker and editor helpers
# fall outside that net and are ignored.
#
# Override the search root with DEV_ROOT (default: $HOME).

DEV_ROOT=${DEV_ROOT:-$HOME}

subtree() {  # print pid + all descendant pids
  local p=$1; printf '%s ' "$p"
  local k; for k in $(pgrep -P "$p" 2>/dev/null); do subtree "$k"; done
}

repo_label() {  # $1 = dir; echo "repo" or "repo/worktree", else fail
  local d=$1 common repo top
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || return 1
  [[ -z $top ]] && return 1
  [[ $top == $DEV_ROOT/* ]] || return 1        # inside dev root
  [[ $top == $HOME/Library/* ]] && return 1    # skip caches/app support

  common=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  repo=${common:h}                             # main repo (worktrees share it)
  if [[ $top == $repo ]]; then
    print -r -- ${repo:t}
  else
    print -r -- ${repo:t}/${top:t}
  fi
}

out=$(
  lsof -nP -iTCP -sTCP:LISTEN -a -u "$USER" 2>/dev/null \
    | awk 'NR>1 {print $2}' | sort -un \
    | while read -r pid; do
        [[ -z $pid ]] && continue

        dir=$(lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | grep '^n' | head -1)
        d=${dir#n}
        label=$(repo_label "$d") || continue

        ports=$(lsof -nP -iTCP -sTCP:LISTEN -a -p "$pid" 2>/dev/null \
                  | awk 'NR>1 {n=$9; sub(/.*:/,"",n); print n}' \
                  | sort -un | paste -sd, -)

        cmd=$(ps -o comm= -p "$pid" 2>/dev/null); cmd=${cmd:t}

        pids=$(subtree "$pid" | tr ' ' '\n' | grep . | paste -sd, -)
        memMB=$(ps -o rss= -p "$pids" 2>/dev/null | awk '{m+=$1} END{printf "%d", m/1024}')

        print -r -- "${memMB:-0}|:$ports  $label  ($cmd)"
      done \
    | sort -t'|' -k1,1 -rn \
    | awk -F'|' '{printf "%6sMB  %s\n", $1, $2}'
)

if [[ -n $out ]]; then
  print -r -- "$out"
else
  print -- "No dev servers running"
fi
