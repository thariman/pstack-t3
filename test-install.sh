#!/usr/bin/env bash
set -euo pipefail
src=$(cd "$(dirname "$0")" && pwd)
# The README's example output names the recorded pstack, and its Files table lists every tracked file.
verified=$(sed -n '1s/^# pstack \([^,]*\),.*/\1/p' "$src/pstack-verified.txt")
for h in upstream claude codex grok agy; do
  grep -qx "$h: pstack $verified" "$src/README.md" || { echo "README: example line '$h: pstack $verified' is missing"; exit 1; }
done
if git -C "$src" rev-parse --git-dir > /dev/null 2>&1; then
  for f in $(git -C "$src" ls-files); do
    case $f in README.md) continue ;; esac
    grep -qF "| \`$f\` |" "$src/README.md" || grep -qF "| \`$(dirname "$f")/\` |" "$src/README.md" \
      || { echo "README: $f is missing from the Files table"; exit 1; }
  done
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo/skills/t3-mode" "$tmp/fixture/skills/poteto-mode" "$tmp/fixture/skills/setup-pstack" "$tmp/fixture/agents" "$tmp/fixture/docs/harness"
cp "$src/install.sh" "$src/check.sh" "$src/profile.sh" "$tmp/repo/"
cp -R "$src/skills/t3-mode/profiles" "$tmp/repo/skills/t3-mode/"
cp "$src/skills/t3-mode/harness-t3.md" "$src/skills/t3-mode/SKILL.md" "$tmp/repo/skills/t3-mode/"
if [ $# -gt 0 ]; then
  cp -R "$1/." "$tmp/fixture/"
else
  printf '{"version":"0.15.36"}\n' > "$tmp/fixture/plugin.json"
  printf 'Use `subagent_type: generalPurpose`.\n' > "$tmp/fixture/skills/poteto-mode/SKILL.md"
  printf 'worker rules\n' > "$tmp/fixture/skills/poteto-mode/worker.md"
  for f in agents/poteto-agent.md agents/comment-sicko.md docs/harness/claude-code.md; do printf 'x\n' > "$tmp/fixture/$f"; done
  { echo '```'; echo '# defaults: 3'; sed -n 's/^\([a-z][^:#]*\): .*/\1: x/p' "$src/skills/t3-mode/profiles/default.md" | grep -v '^one-way door seat'; echo '```'; } \
    > "$tmp/fixture/skills/setup-pstack/SKILL.md"
fi
# A local upstream repo stands in for github.com/cursor/plugins.
mkdir -p "$tmp/upstream"; cp -R "$tmp/fixture" "$tmp/upstream/pstack"
up() { /usr/bin/git -C "$tmp/upstream" -c user.name=t -c user.email=t@t "$@"; }
up init -q; up add -A; up commit -qm v1
upstream_commit() { up add -A; up commit -qm "$1"; }
export TEST_ROOT="$tmp"
export PATH="$tmp/bin:/usr/bin:/bin"
cat > "$tmp/bin/git" <<'STUB'
#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$TEST_ROOT/git.log"
if [ "$1" = clone ]; then
  for dest in "$@"; do :; done
  exec /usr/bin/git clone -q --depth 1 "file://$TEST_ROOT/upstream" "$dest"
elif [ "$1 $2 $3" = "-C $TEST_ROOT/repo rev-parse" ]; then
  cat "$TEST_ROOT/head" 2>/dev/null || echo old
elif [ "$1 $2 $3" = "-C $TEST_ROOT/repo pull" ] && [ -n "${SELF_UPDATE:-}" ] && [ ! -e "$TEST_ROOT/head" ]; then
  echo new > "$TEST_ROOT/head"
  sed -i.bak '4a\
echo new-installer-code-ran' "$TEST_ROOT/repo/install.sh"
elif [ "$1" = -C ] && [ "$2" != "$TEST_ROOT/repo" ]; then
  exec /usr/bin/git "$@"
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
"$tmp/repo/check.sh" --record "$HOME/.local/share/cursor-plugins/pstack" > /dev/null
printf '{"version":"0.15.37"}\n' > "$tmp/upstream/pstack/plugin.json"
printf 'worker rules, new wording\n' > "$tmp/upstream/pstack/skills/poteto-mode/worker.md"
upstream_commit v2
run b
[ "$(backup_count)" = 1 ]
grep -q '^codex: pstack 0.15.37$' "$tmp/output"
grep -q '^review: since pstack 0.15.36, pstack changed skills/poteto-mode/worker.md\.' "$tmp/output"
cp -R "$tmp/fixture" "$tmp/older"; printf '{"version":"0.15.30"}\n' > "$tmp/older/plugin.json"; printf 'old wording\n' > "$tmp/older/skills/poteto-mode/worker.md"
"$tmp/repo/check.sh" "$tmp/older" > "$tmp/older.out"
if grep -q '^review:' "$tmp/older.out"; then exit 1; fi
grep -q -- '-C .*cursor-plugins pull -q --ff-only' "$tmp/git.log"
cat > "$tmp/bin/claude" <<'STUB'
#!/bin/bash
case "$*" in
  'plugin list')
    printf 'pstack@cursor-plugins\n  Version: 0.15.35\n'
    for ((i=0; i<12000; i++)); do printf 'another plugin with a version\n'; done ;;
  'plugin marketplace update cursor-plugins') echo 'marketplace updated' ;;
  'plugin update pstack@cursor-plugins')
    echo update >> "$TEST_ROOT/claude.log"
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
mkdir -p "$HOME/.claude/plugins/marketplaces/cursor-plugins"
cp -R "$tmp/fixture" "$HOME/.claude/plugins/marketplaces/cursor-plugins/pstack"
run c
grep -q '^pstack update failed (claude): network unavailable$' "$tmp/output"
grep -q '^claude: pstack 0.15.35 STALE$' "$tmp/output"
grep -q '^grok: pstack 0.15.35 STALE$' "$tmp/output"
[ ! -e "$HOME/.grok/skills/pstack" ]
[ "$(grep -c update "$tmp/claude.log")" = 1 ]
rm "$HOME/.claude/plugins/marketplaces/cursor-plugins/pstack/skills/poteto-mode/worker.md"
run g
grep -q '^pstack update held (claude): ' "$tmp/output"
grep -q '^  missing in pstack: skills/poteto-mode/worker.md$' "$tmp/output"
[ "$(grep -c update "$tmp/claude.log")" = 1 ]
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
grep -q '^grok: pstack 0.15.37$' "$tmp/output"
export CURL_FAIL=1
bash "$tmp/repo/install.sh" > "$tmp/offline" 2>&1
grep -q '^upstream: pstack unknown$' "$tmp/offline"
if grep -q ' STALE$' "$tmp/offline"; then exit 1; fi
unset CURL_FAIL
HOME=$(mktemp -d "$tmp/home-e.XXXXXX")
SELF_UPDATE=1 run e
[ "$(grep -c '^new-installer-code-ran$' "$tmp/output")" = 1 ]
[ "$(grep -c '^updated pstack-t3 to new, restarting the installer$' "$tmp/output")" = 1 ]
codex_home=$HOME
rm "$tmp/upstream/pstack/skills/poteto-mode/worker.md"
printf '{"version":"0.15.38"}\n' > "$tmp/upstream/pstack/plugin.json"
upstream_commit broken
run f
grep -q '^pstack update held (codex): ' "$tmp/output"
grep -q '^  missing in pstack: skills/poteto-mode/worker.md$' "$tmp/output"
grep -q '^codex: pstack 0.15.37$' "$tmp/output"
[ -f "$HOME/.codex/skills/pstack/skills/poteto-mode/worker.md" ]
HOME=$(mktemp -d "$tmp/home-h.XXXXXX")
mkdir -p "$HOME/.codex/skills"
cp -R "$tmp/fixture" "$HOME/.codex/skills/pstack"
for pass in 1 2; do
  run h
  grep -q "^kept codex's own pstack folder" "$tmp/output"
  [ -d "$HOME/.codex/skills/pstack" ] && [ ! -L "$HOME/.codex/skills/pstack" ]
  [ -f "$HOME/.codex/skills/pstack/skills/poteto-mode/worker.md" ]
  [ ! -d "$HOME/.local/share/pstack-t3/backups" ]
done
git -C "$tmp/upstream" checkout -q HEAD~1 -- pstack && upstream_commit fixed
printf '#!/bin/bash\nexit 0\n' > "$tmp/bin/agy"; chmod +x "$tmp/bin/agy"
HOME=$(mktemp -d "$tmp/home-i.XXXXXX")
run i
grep -q '^registered t3-mode and pstack in ' "$tmp/output"
grep -qF "\"$tmp/repo/skills\"" "$HOME/.gemini/config/skills.json"
grep -qF "\"$HOME/.local/share/cursor-plugins/pstack/skills\"" "$HOME/.gemini/config/skills.json"
grep -q '^agy: pstack 0.15.37$' "$tmp/output"
[ ! -e "$HOME/.agy" ]
run i
if grep -q 'skills.json' "$tmp/output"; then exit 1; fi
printf '{ "entries": [ { "path": "~/mine" } ] }\n' > "$HOME/.gemini/config/skills.json"
run i
grep -q "^skip $HOME/.gemini/config/skills.json: it is not the installer's" "$tmp/output"
[ "$(cat "$HOME/.gemini/config/skills.json")" = '{ "entries": [ { "path": "~/mine" } ] }' ]
rm "$tmp/bin/agy"
HOME=$(mktemp -d "$tmp/home-p.XXXXXX")
"$src/profile.sh" check
"$src/profile.sh" use budget > /dev/null
[ "$(readlink "$HOME/.config/pstack-t3/active.md")" = "$src/skills/t3-mode/profiles/budget.md" ]
"$src/profile.sh"  > "$tmp/prof"; grep -q '^\* budget ' "$tmp/prof"
"$src/profile.sh" show > "$tmp/prof"; grep -q '^swarm workers  *codex/latest-sol low ultrafast$' "$tmp/prof"
"$src/profile.sh" show default > "$tmp/prof"; grep -q '^swarm workers  *codex/latest-sol medium ultrafast$' "$tmp/prof"
rm "$HOME/.config/pstack-t3/active.md"; printf 'hillclimb: codex/latest-sol low ultrafast\n' > "$HOME/.config/pstack-t3/active.md"
"$src/profile.sh" show > "$tmp/prof"; grep -q '^hillclimb  *codex/latest-sol low ultrafast$' "$tmp/prof"
"$src/profile.sh" use budget > /dev/null
mkdir -p "$HOME/.config/pstack-t3/profiles"
printf 'bug-fix: codex/latest-sol high fast\n' > "$HOME/.config/pstack-t3/profiles/mine.md"
"$src/profile.sh" show mine > "$tmp/prof"; grep -q '^bug-fix  *codex/latest-sol high fast$' "$tmp/prof"
"$src/profile.sh" show mine > "$tmp/prof"; grep -q '^hillclimb  *codex/latest-sol high ultrafast$' "$tmp/prof"
if "$src/profile.sh" use mine > "$tmp/lint" 2>&1; then exit 1; fi
grep -q 'fast is Claude only' "$tmp/lint"
: > "$HOME/.config/pstack-t3/profiles/empty.md"
"$src/profile.sh" show empty > "$tmp/prof"; grep -q '^hillclimb  *codex/latest-sol high ultrafast$' "$tmp/prof"
grep -q 'fast is Claude only' "$tmp/lint"
printf 'nope: none\nbug-fix: grok/grok-4.7 mega standard\n' > "$HOME/.config/pstack-t3/profiles/mine.md"
if "$src/profile.sh" check > "$tmp/lint" 2>&1; then exit 1; fi
grep -q 'unknown role "nope"' "$tmp/lint"
grep -q 'unknown effort "mega"' "$tmp/lint"
printf '\nPASS: cases a-i, Antigravity skills.json, no takeover by a failing pstack, pstack gate for Claude and Codex, review notice, backup contents, clone/pull, Grok inheritance, t3-mode preservation, unknown upstream, self-update restart, profiles, empty and default profiles\n'
