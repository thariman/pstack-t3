---
name: t3-mode
description: Run pstack's poteto-mode inside T3 Code, routing subagents across Claude, Codex, Gemini, and Grok with delegate_task. Use for /t3-mode, "t3 mode", "poteto-mode in t3", or before any pstack skill in a T3 Code thread.
---

# T3 mode

1. Find pstack. Use the first command that prints a path:

   ```bash
   ls -d ~/.claude/plugins/cache/cursor-plugins/pstack/*/ 2>/dev/null | sort -V | tail -1
   ls -d ~/.codex/skills/pstack/ ~/.grok/skills/pstack/ ~/.agents/skills/pstack/ ~/.local/share/cursor-plugins/pstack/ 2>/dev/null | head -1
   ```

   That folder is `<pstack>`. If neither prints, stop and tell the user to install pstack.
2. Read `harness-t3.md` next to this file in full. It overrides every Cursor name in pstack.
3. Read `<pstack>/skills/poteto-mode/SKILL.md` in full and run it on the user's task. Put its absolute path in every code-writing brief.

Run any other pstack skill the same way. Do steps 1 and 2, then read and follow that skill's `SKILL.md`.
