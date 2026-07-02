#!/usr/bin/env zsh
# Curl-based installer for dev-servers.
#
#   curl -fsSL https://raw.githubusercontent.com/stuplum/dev-servers/main/install.sh | zsh
#
# Downloads the script to ~/.local/bin/dev-servers and keeps ~/dev-servers.sh
# working for anything already wired to it. Override the ref with DEV_SERVERS_REF.
set -euo pipefail

repo=stuplum/dev-servers
ref=${DEV_SERVERS_REF:-main}
base=https://raw.githubusercontent.com/$repo/$ref
bindir=$HOME/.local/bin
dest=$bindir/dev-servers

mkdir -p "$bindir"
curl -fsSL "$base/dev-servers.sh" -o "$dest"
chmod +x "$dest"
ln -sf "$dest" "$HOME/dev-servers.sh"   # backwards-compat

print "Installed dev-servers -> $dest"
case ":$PATH:" in
  *":$bindir:"*) ;;
  *) print "\n$bindir is not on your PATH. Add to ~/.zshrc:"
     print '  export PATH="$HOME/.local/bin:$PATH"' ;;
esac
