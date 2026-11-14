#!/usr/bin/env bash
# Installs t3-mode and updates pstack for every harness on this machine. Safe to rerun.
# Any machine, first run or rerun: [ -d ~/.local/share/pstack-t3 ] || gh repo clone thariman/pstack-t3 ~/.local/share/pstack-t3; ~/.local/share/pstack-t3/install.sh
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)
plugins=~/.local/share/cursor-plugins

before=$(git -C "$src" rev-parse HEAD 2>/dev/null) || before=""
git -C "$src" pull -q --ff-only 2>/dev/null || echo "note: could not pull $src, using it as is"
# bash keeps running the file it opened, so a pull only takes effect on the next run. Restart once.
after=$(git -C "$src" rev-parse HEAD 2>/dev/null) || after=""
if [ -z "${PSTACK_T3_RESTARTED:-}" ] && [ "$after" != "$before" ]; then
  echo "updated pstack-t3 to ${after:0:7}, restarting the installer"
  PSTACK_T3_RESTARTED=1 exec bash "$src/install.sh" "$@"
fi

link() {
  mkdir -p "$(dirname "$2")"
  if [ -L "$2" ] || [ ! -e "$2" ]; then ln -sfn "$1" "$2" && echo "linked $2 -> $1"
  else echo "skip $2: a real folder is there, remove it to link"; fi
}

found=0
if command -v claude >/dev/null; then
  found=1
  link "$src/skills/t3-mode" ~/.claude/skills/t3-mode
  if [[ $(claude plugin list 2>/dev/null) == *pstack@cursor-plugins* ]]; then
    err=$(mktemp)
    if { claude plugin marketplace update cursor-plugins && claude plugin update pstack@cursor-plugins; } 2>"$err"; then
      cat "$err" >&2
    else
      cat "$err" >&2
      echo "pstack update failed (claude): $(tail -n 1 "$err")"
    fi
    rm -f "$err"
  else
    claude plugin marketplace add cursor/plugins
    claude plugin install pstack@cursor-plugins
  fi
fi

# Codex and Grok load pstack from a skills folder. Grok also reads ~/.claude/skills and Claude
# plugins, so with Claude present it already has both, and linking again would load pstack twice.
for h in codex grok; do
  command -v $h >/dev/null || continue
  found=1
  [ $h = grok ] && command -v claude >/dev/null && { echo "grok: uses Claude's t3-mode and pstack"; continue; }
  link "$src/skills/t3-mode" ~/.$h/skills/t3-mode
  copies=("$HOME/.$h/skills/pstack")
  [ "$h" != codex ] || copies+=("$HOME/.agents/skills/pstack")
  for p in "${copies[@]}"; do
    if [ -d "$p" ] && [ ! -L "$p" ]; then
      backup="$HOME/.local/share/pstack-t3/backups/$h-$(basename "$(dirname "$(dirname "$p")")" | tr -d .)-pstack"
      dest="$backup-$(date +%Y%m%d-%H%M%S)"
      while [ -e "$dest" ]; do sleep 1; dest="$backup-$(date +%Y%m%d-%H%M%S)"; done
      mkdir -p "$(dirname "$dest")"
      mv "$p" "$dest"
      echo "moved $p -> $dest"
    fi
  done
  if [ -d "$plugins/.git" ]; then
    git -C "$plugins" pull -q --ff-only
  else
    mkdir -p "$(dirname "$plugins")"
    git clone -q --depth 1 https://github.com/cursor/plugins "$plugins"
  fi
  link "$plugins/pstack" ~/.$h/skills/pstack
done

[ $found = 1 ] || { echo "no claude, codex or grok on PATH, nothing to install"; exit 1; }
version() { sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$@" 2>/dev/null | sed -n '1p'; }
upstream=$(curl -fsS https://raw.githubusercontent.com/cursor/plugins/main/pstack/plugin.json 2>/dev/null) || upstream=""
upstream=$(version <<<"$upstream")
upstream=${upstream:-unknown}
echo "upstream: pstack $upstream"
claude_version=""
for h in claude codex grok; do
  command -v "$h" >/dev/null || continue
  if [ "$h" = claude ]; then
    listing=$(claude plugin list 2>/dev/null) || listing=""
    v=$(sed -n '/pstack@cursor-plugins/,/Version:/{s/.*Version:[[:space:]]*//p;}' <<<"$listing" | sed -n '1p')
    claude_version=$v
  elif [ "$h" = grok ] && command -v claude >/dev/null; then v=$claude_version
  else v=$(version "$HOME/.$h/skills/pstack/plugin.json"); fi
  v=${v:-unknown}
  stale=""
  [ "$upstream" = unknown ] || [ "$v" = "$upstream" ] || stale=" STALE"
  echo "$h: pstack $v$stale"
done
"$src/check.sh"
