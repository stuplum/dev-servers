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
# Usage:
#   dev-servers            list running dev servers
#   dev-servers -t         live TUI: navigate, multi-select, force-stop
#
# Env: DEV_ROOT (search root, default $HOME), DEV_SERVERS_INTERVAL (TUI refresh
# seconds, default 2).

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

# One row per server, sorted by memory desc. Fields (|-separated):
#   rootpid | memMB | ":ports  label  (cmd)" | subtree-pids(csv)
collect() {
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

        print -r -- "$pid|${memMB:-0}|:$ports  $label  ($cmd)|$pids"
      done \
    | sort -t'|' -k2,2 -rn
}

list() {
  local raw; raw=$(collect)
  if [[ -z $raw ]]; then print -- "No dev servers running"; return; fi
  print -r -- "$raw" | awk -F'|' '{printf "%6sMB  %s\n", $2, $3}'
}

stop_pids() {  # $@ = csv pid-lists; TERM, then KILL survivors
  local csv p; local -a all
  for csv in "$@"; do all+=(${(s:,:)csv}); done
  kill -TERM $all 2>/dev/null
  sleep 1
  for p in $all; do kill -0 $p 2>/dev/null && kill -KILL $p 2>/dev/null; done
}

tui() {
  # All variables declared once — re-declaring a set var with `local` echoes it.
  local interval=${DEV_SERVERS_INTERVAL:-2} saved k seq row rpid mem disp mark point line ans cols w
  local -a rows targets
  local -A selected
  integer cursor=1 r last=-1000000 winch=1 dirty=1 tty ln term_h top=1 vis slot i

  # The TUI is a persistent, self-refreshing, interactive program. If stdout is
  # not a terminal it's being wrapped (e.g. `watch`) or piped, which swallows
  # keystrokes and restarts it — refuse with a clear hint instead of misbehaving.
  if [[ ! -t 1 ]]; then
    print -u2 "dev-servers -t is an interactive TUI that refreshes itself — run it directly,"
    print -u2 "not under 'watch' or a pipe. Just:  dev-servers -t"
    return 1
  fi

  # Open the controlling terminal on a dedicated fd and drive BOTH raw-mode and
  # key reads through it — zsh's `read -k` reads /dev/tty, so setting stty on
  # fd 0 alone leaves reads in cooked mode (echoed keys) when they differ.
  if ! exec {tty}<>/dev/tty; then
    print -u2 "dev-servers -t needs a terminal — run it in a terminal window."
    return 1
  fi

  saved=$(stty -g <&$tty 2>/dev/null)
  stty -echo -icanon <&$tty 2>/dev/null
  print -n '\e[?1049h\e[?25l\e[?7l'                  # alt screen, hide cursor, no wrap
  trap "stty \"\$saved\" <&$tty 2>/dev/null; print -n '\\e[?7h\\e[?25h\\e[?1049l'" EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'winch=1' WINCH                               # redraw on resize

  while true; do
    # Collect only on the timer or after a refresh/kill — never per keystroke.
    if (( SECONDS - last >= interval )); then
      rows=("${(@f)$(collect)}"); [[ -z $rows[1] ]] && rows=(); last=$SECONDS; dirty=1
    fi
    if (( winch )); then                            # resize: re-measure, full clear
      winch=0; dirty=1
      cols=$(stty size <&$tty 2>/dev/null)         # "rows cols"
      term_h=${cols%% *}                           # first token = row count
      cols=${cols##* }                             # last token = column count
      [[ $cols == <-> ]] || cols=80                # integer glob: fall back if junk
      [[ $term_h == <-> ]] || term_h=24
      (( cols < 20 )) && cols=80
      (( term_h < 6 )) && term_h=24
      w=$(( cols - 1 ))                            # leave the last column untouched
      print -n '\e[2J'
    fi
    (( cursor > ${#rows} )) && cursor=${#rows}
    (( cursor < 1 )) && cursor=1

    if (( dirty )); then                            # redraw only when something changed
      dirty=0
      # Absolute positioning per line (\e[row;1H) + clear-line (\e[K); never relies
      # on newline/autowrap/scroll behaviour, which varies by terminal. Rows live in
      # a scrolling viewport between a fixed header (rows 1-2) and a sticky footer
      # (last row), so the legend never scrolls away.
      vis=$(( term_h - 4 )); (( vis < 1 )) && vis=1     # visible row slots
      (( cursor < top )) && top=$cursor                # scroll up to reveal cursor
      (( cursor > top + vis - 1 )) && top=$(( cursor - vis + 1 ))
      (( top < 1 )) && top=1

      printf '\e[1;1H\e[K\e[1m dev-servers\e[0m \e[2m(%ss · %d up · %d selected)\e[0m' \
             "$interval" ${#rows} ${#selected}
      printf '\e[2;1H\e[K'
      if (( ${#rows} == 0 )); then
        printf '\e[3;1H\e[K  no dev servers running'
        for (( slot=1; slot < vis; slot++ )); do printf '\e[%d;1H\e[K' $(( 3 + slot )); done
      else
        for (( slot=0; slot < vis; slot++ )); do
          ln=$(( 3 + slot )); i=$(( top + slot ))
          if (( i > ${#rows} )); then printf '\e[%d;1H\e[K' $ln; continue; fi
          row=$rows[$i]
          rpid=${row%%|*}; row=${row#*|}
          mem=${row%%|*};  disp=${${row#*|}%|*}
          mark='[ ]'; [[ -n ${selected[$rpid]} ]] && mark='[x]'
          point='  '; (( i == cursor )) && point='> '
          printf -v line '%s%s %6sMB  %s' "$point" "$mark" "$mem" "$disp"  # no subshell
          line=${line[1,$w]}                        # truncate so nothing wraps
          if (( i == cursor )); then printf '\e[%d;1H\e[K\e[7m%s\e[0m' $ln "$line"
          else                       printf '\e[%d;1H\e[K%s' $ln "$line"; fi
        done
      fi
      printf '\e[%d;1H\e[K' $(( term_h - 1 ))       # blank line above footer
      line=' ↑/↓ move · space select · a all · n none · x stop · r refresh · q quit'
      printf '\e[%d;1H\e[K\e[2m%s\e[0m' $term_h "${line[1,$w]}"   # sticky footer
    fi

    read -u $tty -t 1 -k 1 k || continue            # 1s poll; keypress returns instantly
    dirty=1
    case $k in
      $'\e')                                        # escape / arrow
        if read -u $tty -t 1 -k 2 seq; then
          case $seq in
            '[A'|'OA') (( cursor-- ));;             # up   (CSI or SS3/application mode)
            '[B'|'OB') (( cursor++ ));;             # down
          esac
        else break; fi                              # bare ESC quits
        ;;
      k|K) (( cursor-- ));;
      j|J) (( cursor++ ));;
      ' ')
        if (( ${#rows} )); then
          rpid=${rows[$cursor]%%|*}
          [[ -n ${selected[$rpid]} ]] && unset "selected[$rpid]" || selected[$rpid]=1
        fi
        ;;
      a|A) for row in $rows; do selected[${row%%|*}]=1; done;;
      n|N) selected=();;
      r|R) last=-1000000;;                          # force refresh next loop
      x|X|$'\n'|$'\r')                              # stop ONLY explicitly selected rows
        targets=()
        for row in $rows; do [[ -n ${selected[${row%%|*}]} ]] && targets+=("${row##*|}"); done
        if (( ${#targets} )); then
          printf '\e[%d;1H\e[K \e[1mForce-stop %d selected server(s)? [y/N]\e[0m ' $term_h ${#targets}
          read -u $tty -k 1 ans
          [[ $ans == (y|Y) ]] && { stop_pids "${targets[@]}"; selected=(); }
          last=-1000000                             # refresh after kill/confirm
        fi
        ;;
      q|Q) break;;
    esac
  done

  stty "$saved" <&$tty 2>/dev/null; print -n '\e[?7h\e[?25h\e[?1049l'
  trap - EXIT INT TERM WINCH
  exec {tty}>&-                                      # close the terminal fd
}

case ${1:-} in
  -t|--tui|--watch) tui;;
  -h|--help) print -- "usage: dev-servers [-t|--tui]";;
  *) list;;
esac
