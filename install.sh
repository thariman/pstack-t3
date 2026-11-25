#!/usr/bin/env bash
# Installs t3-mode and updates pstack for every harness on this machine. Safe to rerun.
# Any machine, first run or rerun: [ -d ~/.local/share/pstack-t3 ] || git clone https://github.com/thariman/pstack-t3 ~/.local/share/pstack-t3; ~/.local/share/pstack-t3/install.sh
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

# A harness is installed when its command is on PATH. T3 Code also ships its own Antigravity.
has() { command -v "$1" >/dev/null || { [ "$1" = agy ] && [ -d ~/.t3/userdata/providers/antigravity ]; }; }
have=""; missing=""
for h in claude codex grok agy; do if has $h; then have="$have $h"; else missing="$missing $h"; fi; done
echo "harnesses on this machine:${have:- none}${missing:+. Not here, skipped:$missing}"

link() {
  mkdir -p "$(dirname "$2")"
  if [ -L "$2" ] || [ ! -e "$2" ]; then ln -sfn "$1" "$2" && echo "linked $2 -> $1"
  else echo "skip $2: a real folder is there, remove it to link"; fi
}

# Checks a new pstack against t3-mode. On failure the harness keeps the pstack it has.
gate() {
  local out
  if out=$("$src/check.sh" "$1" 2>&1); then return 0; fi
  if [ "${3:-}" = installed ]; then echo "warning ($2): t3-mode does not match this pstack yet:"
  else echo "pstack update held ($2): the new pstack does not match t3-mode, so $2 keeps its current pstack:"; fi
  printf '%s\n' "$out" | sed 's/^/  /'
  return 1
}

# Backups live beside the clone, never inside ~/.local/share/pstack-t3, so the install one-liner's
# folder test only ever sees a real clone. Older installers put them there, so move those out.
backups=~/.local/share/pstack-t3-backups
old_backups=~/.local/share/pstack-t3/backups
if [ -d "$old_backups" ] && [ "$src" != ~/.local/share/pstack-t3 ]; then
  mkdir -p "$backups"; mv "$old_backups"/* "$backups"/ 2>/dev/null || true
  rmdir "$old_backups" ~/.local/share/pstack-t3 2>/dev/null || true
  echo "moved old backups to $backups"
fi

found=0
pulled=""
clone_fails=""
if command -v claude >/dev/null; then
  found=1
  link "$src/skills/t3-mode" ~/.claude/skills/t3-mode
  if [[ $(claude plugin list 2>/dev/null) == *pstack@cursor-plugins* ]]; then
    err=$(mktemp)
    # The marketplace update downloads the new pstack. Check it before the plugin update installs it.
    if ! claude plugin marketplace update cursor-plugins 2>"$err"; then
      cat "$err" >&2
      echo "pstack update failed (claude): $(tail -n 1 "$err")"
    elif gate ~/.claude/plugins/marketplaces/cursor-plugins/pstack claude; then
      if claude plugin update pstack@cursor-plugins 2>"$err"; then cat "$err" >&2
      else cat "$err" >&2; echo "pstack update failed (claude): $(tail -n 1 "$err")"; fi
    fi
    rm -f "$err"
  else
    claude plugin marketplace add cursor/plugins
    claude plugin install pstack@cursor-plugins
    gate ~/.claude/plugins/marketplaces/cursor-plugins/pstack claude installed || true
  fi
fi

# Antigravity reads skills only from folders listed in ~/.gemini/config/skills.json, one level deep.
agy_skills() {
  local f=~/.gemini/config/skills.json
  if [ ! -e "$f" ]; then
    mkdir -p "$(dirname "$f")"
    printf '{\n  "entries": [\n    { "path": "%s" },\n    { "path": "%s" }\n  ]\n}\n' "$src/skills" "$plugins/pstack/skills" > "$f"
    echo "registered t3-mode and pstack in $f"
  elif ! grep -qF "\"$src/skills\"" "$f" || ! grep -qF "\"$plugins/pstack/skills\"" "$f"; then
    echo "skip $f: it is not the installer's. Add { \"path\": \"$src/skills\" } and { \"path\": \"$plugins/pstack/skills\" } to its entries."
  fi
}

# Codex, Grok, and Antigravity load pstack from the managed clone. Grok also reads ~/.claude/skills and
# Claude plugins, so with Claude present it already has both, and linking again would load pstack twice.
for h in codex grok agy; do
  has $h || continue
  found=1
  [ $h = grok ] && command -v claude >/dev/null && { echo "grok: uses Claude's t3-mode and pstack"; continue; }
  [ $h = agy ] || link "$src/skills/t3-mode" ~/.$h/skills/t3-mode
  # Update or clone the managed copy first, so a pstack that fails the check never replaces one that works.
  if [ -n "$pulled" ]; then :
  elif [ -d "$plugins/.git" ]; then
    old=$(git -C "$plugins" rev-parse HEAD)
    git -C "$plugins" pull -q --ff-only
    if [ "$(git -C "$plugins" rev-parse HEAD)" != "$old" ] && ! gate "$plugins/pstack" "$h"; then
      git -C "$plugins" reset -q --hard "$old"
    fi
  else
    mkdir -p "$(dirname "$plugins")"
    git clone -q --depth 1 https://github.com/cursor/plugins "$plugins"
  fi
  [ -n "$pulled" ] || "$src/check.sh" "$plugins/pstack" >/dev/null 2>&1 || clone_fails=1
  pulled=1
  if [ $h = agy ]; then
    [ -z "$clone_fails" ] || gate "$plugins/pstack" "$h" installed || true
    agy_skills
    continue
  fi
  copies=("$HOME/.$h/skills/pstack")
  [ "$h" != codex ] || copies+=("$HOME/.agents/skills/pstack")
  keep=""
  for p in "${copies[@]}"; do
    [ -d "$p" ] && [ ! -L "$p" ] || continue
    if [ -n "$clone_fails" ]; then keep=1; continue; fi
    backup="$backups/$h-$(basename "$(dirname "$(dirname "$p")")" | tr -d .)-pstack"
    dest="$backup-$(date +%Y%m%d-%H%M%S)"
    while [ -e "$dest" ]; do sleep 1; dest="$backup-$(date +%Y%m%d-%H%M%S)"; done
    mkdir -p "$(dirname "$dest")"
    mv "$p" "$dest"
    echo "moved $p -> $dest"
  done
  if [ -n "$keep" ]; then
    gate "$plugins/pstack" "$h" || true
    echo "kept $h's own pstack folder. The installer takes it over once upstream matches t3-mode."
    continue
  fi
  [ -z "$clone_fails" ] || gate "$plugins/pstack" "$h" installed || true
  link "$plugins/pstack" ~/.$h/skills/pstack
done

[ $found = 1 ] || { echo "no claude, codex, grok or agy on PATH, nothing to install"; exit 1; }
version() { sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$@" 2>/dev/null | sed -n '1p'; }
upstream=$(curl -fsS https://raw.githubusercontent.com/cursor/plugins/main/pstack/plugin.json 2>/dev/null) || upstream=""
upstream=$(version <<<"$upstream")
upstream=${upstream:-unknown}
echo "upstream: pstack $upstream"
claude_version=""
for h in claude codex grok agy; do
  has "$h" || continue
  if [ "$h" = claude ]; then
    listing=$(claude plugin list 2>/dev/null) || listing=""
    v=$(sed -n '/pstack@cursor-plugins/,/Version:/{s/.*Version:[[:space:]]*//p;}' <<<"$listing" | sed -n '1p')
    claude_version=$v
  elif [ "$h" = grok ] && command -v claude >/dev/null; then v=$claude_version
  elif [ "$h" = agy ]; then v=$(version "$plugins/pstack/plugin.json")
  else v=$(version "$HOME/.$h/skills/pstack/plugin.json"); fi
  v=${v:-unknown}
  stale=""
  [ "$upstream" = unknown ] || [ "$v" = "$upstream" ] || stale=" STALE"
  echo "$h: pstack $v$stale"
done
"$src/check.sh"
"$src/profile.sh" check
