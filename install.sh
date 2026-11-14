#!/usr/bin/env bash
# Installs t3-mode, plus pstack where it is missing, for every harness on this machine. Safe to rerun.
# Fresh machine: gh repo clone thariman/pstack-t3 ~/.local/share/pstack-t3 && ~/.local/share/pstack-t3/install.sh
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)
plugins=~/.local/share/cursor-plugins

git -C "$src" pull -q --ff-only 2>/dev/null || echo "note: could not pull $src, using it as is"

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
    claude plugin update pstack@cursor-plugins >/dev/null 2>&1 || true
  else
    claude plugin marketplace add cursor/plugins
    claude plugin install pstack@cursor-plugins
  fi
fi

if command -v codex >/dev/null; then
  found=1
  link "$src/skills/t3-mode" ~/.codex/skills/t3-mode
  if [ -d "$plugins/.git" ]; then
    git -C "$plugins" pull -q --ff-only
  elif [ ! -e ~/.codex/skills/pstack ] && [ ! -e ~/.agents/skills/pstack ]; then
    git clone -q --depth 1 https://github.com/cursor/plugins "$plugins"
  fi
  [ -d "$plugins/pstack" ] && link "$plugins/pstack" ~/.codex/skills/pstack
fi

[ $found = 1 ] || { echo "no claude or codex on PATH, nothing to install"; exit 1; }
"$src/check.sh"
