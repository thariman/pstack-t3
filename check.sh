#!/usr/bin/env bash
# Fails when pstack starts using a Cursor name that harness-t3.md does not map.
set -euo pipefail
map="$(dirname "$0")/skills/t3-mode/harness-t3.md"
pstack=${1:-}
for p in $(ls -d ~/.claude/plugins/cache/cursor-plugins/pstack/*/ 2>/dev/null | sort -rV) ~/.codex/skills/pstack ~/.agents/skills/pstack; do
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
[ $missing = 0 ] && echo "ok: every Cursor name pstack uses is mapped ($pstack)"
exit $missing
