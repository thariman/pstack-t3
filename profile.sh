#!/usr/bin/env bash
# Lists, shows, switches, and checks t3-mode model profiles.
#   profile.sh              list profiles, * marks the active one
#   profile.sh show [name]  print every role with its model, effort, and speed
#   profile.sh use <name>   make <name> the active profile on this machine
#   profile.sh check        validate every profile
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
builtin_dir="$here/skills/t3-mode/profiles"
user_dir=~/.config/pstack-t3/profiles
active=~/.config/pstack-t3/active.md

find_profile() {
  for d in "$user_dir" "$builtin_dir"; do
    [ -f "$d/$1.md" ] && { echo "$d/$1.md"; return; }
  done
  echo "no profile named $1" >&2; exit 1
}

active_name() {
  if [ -L "$active" ]; then basename "$(readlink "$active")" .md; else echo default; fi
}

# Prints problems in a profile, one per line. Prints nothing when it is valid.
lint() {
  awk -v file="$1" -v defaults="$builtin_dir/default.md" '
    BEGIN {
      while ((getline line < defaults) > 0) if (line !~ /^#/ && line ~ /: /) { split(line, kv, ": "); known[kv[1]] = 1 }
      split("low medium high xhigh max", e, " "); for (i in e) effort[e[i]] = 1
    }
    /^#/ || /^[[:space:]]*$/ { next }
    {
      i = index($0, ": ")
      if (!i) { print file ":" NR ": no \"role: value\" in: " $0; next }
      role = substr($0, 1, i - 1); value = substr($0, i + 2)
      if (!(role in known)) print file ":" NR ": unknown role \"" role "\""
      if (value == "none") next
      n = split(value, seats, ", ")
      for (s = 1; s <= n; s++) {
        if (split(seats[s], t, " ") != 3 || split(t[1], pm, "/") != 2) { print file ":" NR ": seat \"" seats[s] "\" is not provider/model effort speed"; continue }
        if (pm[1] !~ /^(claudeAgent|codex|grok|antigravity)$/) print file ":" NR ": unknown provider \"" pm[1] "\""
        if (!(t[2] in effort)) print file ":" NR ": unknown effort \"" t[2] "\""
        if (t[3] == "fast" && pm[1] != "claudeAgent") print file ":" NR ": fast is Claude only"
        else if (t[3] == "ultrafast" && pm[1] != "codex") print file ":" NR ": ultrafast is Codex only"
        else if (t[3] !~ /^(standard|fast|ultrafast)$/) print file ":" NR ": unknown speed \"" t[3] "\""
      }
    }' "$1"
}

case "${1:-list}" in
  list)
    now=$(active_name)
    for f in "$builtin_dir"/*.md "$user_dir"/*.md; do
      [ -f "$f" ] || continue
      n=$(basename "$f" .md); mark=" "; [ "$n" = "$now" ] && mark="*"
      echo "$mark $n  $(sed -n '1s/^# t3-mode profile: [^.]*\. *//p' "$f")"
    done ;;
  show)
    name=${2:-$(active_name)}; f=$(find_profile "$name")
    echo "profile: $name ($f)"
    # Roles the profile leaves out keep the default profile's line.
    awk 'NR == FNR { if ($0 !~ /^#/ && index($0, ": ")) over[substr($0, 1, index($0, ": ") - 1)] = substr($0, index($0, ": ") + 2); next }
         /^#/ || !index($0, ": ") { next }
         { role = substr($0, 1, index($0, ": ") - 1); v = (role in over) ? over[role] : substr($0, index($0, ": ") + 2)
           n = split(v, seats, ", "); printf "%-24s %s\n", role, seats[1]; for (s = 2; s <= n; s++) printf "%-24s %s\n", "", seats[s] }' \
      "$f" "$builtin_dir/default.md" ;;
  use)
    [ -n "${2:-}" ] || { echo "usage: profile.sh use <name>"; exit 1; }
    f=$(find_profile "$2"); problems=$(lint "$f")
    [ -z "$problems" ] || { echo "$problems"; exit 1; }
    mkdir -p "$(dirname "$active")"; ln -sfn "$f" "$active"
    echo "active profile: $2. New t3-mode tasks use it." ;;
  check)
    problems=$(for f in "$builtin_dir"/*.md "$user_dir"/*.md; do if [ -f "$f" ]; then lint "$f"; fi; done)
    [ -z "$problems" ] || { echo "$problems"; exit 1; }
    echo "ok: every profile parses" ;;
  *) sed -n '2,6s/^# //p' "$0"; exit 1 ;;
esac
