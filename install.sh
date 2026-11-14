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

# Codex and Grok load pstack from a skills folder. Grok also reads ~/.claude/skills and Claude
# plugins, so with Claude present it already has both, and linking again would load pstack twice.
for h in codex grok; do
  command -v $h >/dev/null || continue
  found=1
  [ $h = grok ] && command -v claude >/dev/null && { echo "grok: uses Claude's t3-mode and pstack"; continue; }
  link "$src/skills/t3-mode" ~/.$h/skills/t3-mode
  if [ -d "$plugins/.git" ]; then
    git -C "$plugins" pull -q --ff-only
  elif [ ! -e ~/.$h/skills/pstack ] && [ ! -e ~/.agents/skills/pstack ]; then
    git clone -q --depth 1 https://github.com/cursor/plugins "$plugins"
  fi
  [ -d "$plugins/pstack" ] && link "$plugins/pstack" ~/.$h/skills/pstack
done

[ $found = 1 ] || { echo "no claude, codex or grok on PATH, nothing to install"; exit 1; }
"$src/check.sh"
