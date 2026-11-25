#!/usr/bin/env bash
# Fails when pstack uses a Cursor name, file, or role that t3-mode does not match.
# ./check.sh [pstack path]           check the newest installed pstack, or the one given
# ./check.sh --record [pstack path]  check, then record it as read and verified by hand
set -euo pipefail
map="$(dirname "$0")/skills/t3-mode/harness-t3.md"
record="$(dirname "$0")/pstack-verified.txt"
recording=""; [ "${1:-}" != --record ] || { recording=1; shift; }
pstack=${1:-}
for p in $(ls -d ~/.claude/plugins/cache/cursor-plugins/pstack/*/ 2>/dev/null | sort -rV) ~/.codex/skills/pstack ~/.grok/skills/pstack ~/.agents/skills/pstack; do
  [ -z "$pstack" ] && [ -f "$p/skills/poteto-mode/SKILL.md" ] && pstack=$p
done
[ -f "$pstack/skills/poteto-mode/SKILL.md" ] || { echo "no pstack at '$pstack'"; exit 2; }

names=$(grep -rhoE '`(subagent_type|readonly|environment|cloud_base_branch|run_in_background|resume|file_attachments): ?"?[A-Za-z_-]*' "$pstack/skills" "$pstack/agents" \
  | tr -d '`"' | sed 's/: */: /' | sort -u)
names+=$'\n'"AskQuestion"$'\n'"pstack-models.mdc"$'\n'"watch-pr"$'\n'"Bugbot"$'\n'"Origin"$'\n'"poteto-agent"$'\n'"comment-sicko"

missing=0
while read -r n; do
  [ -z "$n" ] && continue
  key=${n%%: *}; val=${n#*: }; [ "$key" = "$n" ] && val=""
  grep -qF "$key" "$map" && { [ -z "$val" ] || grep -qF "$val" "$map"; } || { echo "unmapped: $n"; missing=1; }
done <<<"$names"

# Every pstack file t3-mode tells an agent to read must exist.
skill="$(dirname "$0")/skills/t3-mode"
for f in $(grep -ohE '<(abs path|pstack)>/[A-Za-z0-9_./-]+' "$map" "$skill/SKILL.md" | sed -E 's/^<[^>]+>\///' | sort -u) agents/poteto-agent.md; do
  [ -e "$pstack/$f" ] || { echo "missing in pstack: $f"; missing=1; }
done

# Profile roles must match pstack's roles. `one-way door seat` is t3-mode's own.
pstack_roles=$(sed -n '/^# defaults:/,/^```/p' "$pstack/skills/setup-pstack/SKILL.md" | sed -n 's/^\([a-z][^:#]*\): .*/\1/p' | sort -u)
ours=$(sed -n 's/^\([a-z][^:#]*\): .*/\1/p' "$skill/profiles/default.md" | grep -vx 'one-way door seat' | sort -u)
[ -n "$pstack_roles" ] || { echo "no role list in pstack's setup-pstack"; missing=1; }
for r in $(comm -23 <(echo "$ours") <(echo "$pstack_roles") | tr ' ' '~'); do echo "retired role in profiles: ${r//\~/ }"; missing=1; done
for r in $(comm -13 <(echo "$ours") <(echo "$pstack_roles") | tr ' ' '~'); do echo "new pstack role missing from profiles/default.md: ${r//\~/ }"; missing=1; done

# The files t3-mode follows closely. A change in them needs a person or a review agent to read it.
watched="skills/poteto-mode/SKILL.md skills/poteto-mode/worker.md skills/setup-pstack/SKILL.md docs/harness/claude-code.md agents/poteto-agent.md agents/comment-sicko.md"
sums() { (cd "$pstack" && for f in $watched; do if [ -f "$f" ]; then cksum "$f"; fi; done); }
version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pstack/plugin.json" 2>/dev/null | sed -n '1p')

[ $missing = 0 ] || exit 1
echo "ok: every Cursor name, file, and role t3-mode uses matches pstack ($pstack)"
if [ -n "$recording" ]; then
  { echo "# pstack ${version:-unknown}, read and verified by hand"; sums; } > "$record"
  echo "recorded pstack ${version:-unknown} as verified in $record"
elif [ -f "$record" ]; then
  changed=$(comm -13 <(sed 1d "$record" | sort) <(sums | sort) | awk '{print $3}' | tr '\n' ' ')
  [ -z "$changed" ] || echo "review: since $(sed -n '1s/^# //;1s/,.*//p' "$record"), pstack changed ${changed% }. Read the diff, update t3-mode if needed, then run ./check.sh --record."
fi
