#!/usr/bin/env bash
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo/skills/t3-mode" "$tmp/fixture/skills/poteto-mode" "$tmp/fixture/agents"
cp "$src/install.sh" "$src/check.sh" "$tmp/repo/"
cp "$src/skills/t3-mode/harness-t3.md" "$tmp/repo/skills/t3-mode/"
if [ $# -gt 0 ]; then
  cp -R "$1/." "$tmp/fixture/"
else
  printf '{"version":"0.15.36"}\n' > "$tmp/fixture/plugin.json"
  printf 'Use `subagent_type: generalPurpose`.\n' > "$tmp/fixture/skills/poteto-mode/SKILL.md"
fi
export TEST_ROOT="$tmp"
export PATH="$tmp/bin:/usr/bin:/bin"
cat > "$tmp/bin/git" <<'STUB'
#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$TEST_ROOT/git.log"
if [ "$1" = clone ]; then
  for dest in "$@"; do :; done
  mkdir -p "$dest/.git"
  cp -R "$TEST_ROOT/fixture" "$dest/pstack"
elif [ "$1" = -C ] && [ "$2" != "$TEST_ROOT/repo" ]; then
  cp "$TEST_ROOT/fixture/plugin.json" "$2/pstack/plugin.json"
fi
STUB
cat > "$tmp/bin/curl" <<'STUB'
#!/bin/bash
[ "${CURL_FAIL:-0}" = 0 ] || exit 22
printf '{"version":"0.15.37"}\n'
STUB
printf '#!/bin/bash\nexit 0\n' > "$tmp/bin/codex"
chmod +x "$tmp/bin/"*
run() {
  local label=$1
  bash "$tmp/repo/install.sh" > "$tmp/output" 2>&1
  printf '\ncase %s\n' "$label"
  cat "$tmp/output"
  grep -q '^upstream: pstack ' "$tmp/output"
  grep -q '^codex: pstack ' "$tmp/output"
  grep -q '^ok: every Cursor name' "$tmp/output"
}
backup_count() {
  find "$HOME/.local/share/pstack-t3/backups" -name '*-pstack-*' -type d | wc -l | tr -d ' '
}
export HOME
HOME=$(mktemp -d "$tmp/home-a.XXXXXX")
mkdir -p "$HOME/.codex/skills"
cp -R "$tmp/fixture" "$HOME/.codex/skills/pstack"
run a
[ -L "$HOME/.codex/skills/pstack" ]
[ "$(backup_count)" = 1 ]
backup=$(find "$HOME/.local/share/pstack-t3/backups" -name 'codex-codex-pstack-*' -type d)
diff -r "$tmp/fixture" "$backup"
[ "$(find "$HOME/.codex/skills" -type d -name pstack | wc -l | tr -d ' ')" = 0 ]
grep -q '^codex: pstack 0.15.36 STALE$' "$tmp/output"
printf '{"version":"0.15.35"}\n' > "$HOME/.local/share/cursor-plugins/pstack/plugin.json"
run b
[ "$(backup_count)" = 1 ]
grep -q '^codex: pstack 0.15.36 STALE$' "$tmp/output"
grep -q -- '-C .*cursor-plugins pull -q --ff-only' "$tmp/git.log"
cat > "$tmp/bin/claude" <<'STUB'
#!/bin/bash
case "$*" in
  'plugin list')
    printf 'pstack@cursor-plugins\n  Version: 0.15.35\n'
    for ((i=0; i<12000; i++)); do printf 'another plugin with a version\n'; done ;;
  'plugin marketplace update cursor-plugins') echo 'marketplace updated' ;;
  'plugin update pstack@cursor-plugins')
    printf 'update started\nnetwork unavailable\n' >&2
    exit 1 ;;
  *) exit 1 ;;
esac
STUB
printf '#!/bin/bash\nexit 0\n' > "$tmp/bin/grok"
chmod +x "$tmp/bin/claude" "$tmp/bin/grok"
HOME=$(mktemp -d "$tmp/home-c.XXXXXX")
mkdir -p "$HOME/.claude/plugins/cache/cursor-plugins/pstack"
cp -R "$tmp/fixture" "$HOME/.claude/plugins/cache/cursor-plugins/pstack/0.15.35"
run c
grep -q '^pstack update failed (claude): network unavailable$' "$tmp/output"
grep -q '^claude: pstack 0.15.35 STALE$' "$tmp/output"
grep -q '^grok: pstack 0.15.35 STALE$' "$tmp/output"
[ ! -e "$HOME/.grok/skills/pstack" ]
rm "$tmp/bin/claude"
HOME=$(mktemp -d "$tmp/home-d.XXXXXX")
for h in codex agents grok; do
  mkdir -p "$HOME/.$h/skills"
  cp -R "$tmp/fixture" "$HOME/.$h/skills/pstack"
done
mkdir -p "$HOME/.codex/skills/t3-mode"
printf 'keep\n' > "$HOME/.codex/skills/t3-mode/keep"
run d
[ "$(backup_count)" = 3 ]
[ ! -e "$HOME/.agents/skills/pstack" ]
for h in codex grok; do
  [ -L "$HOME/.$h/skills/pstack" ]
  [ "$(readlink "$HOME/.$h/skills/pstack")" = "$HOME/.local/share/cursor-plugins/pstack" ]
  [ "$(find "$HOME/.$h/skills" -type d -name pstack | wc -l | tr -d ' ')" = 0 ]
done
[ "$(cat "$HOME/.codex/skills/t3-mode/keep")" = keep ]
grep -q '^grok: pstack 0.15.36 STALE$' "$tmp/output"
export CURL_FAIL=1
bash "$tmp/repo/install.sh" > "$tmp/offline" 2>&1
grep -q '^upstream: pstack unknown$' "$tmp/offline"
if grep -q ' STALE$' "$tmp/offline"; then exit 1; fi
printf '\nPASS: cases a-d, backup contents, clone/pull, Grok inheritance, t3-mode preservation, and unknown upstream\n'
