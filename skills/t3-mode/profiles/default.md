# t3-mode profile: default. Four-vendor panels, code on Codex Sol.
# Line: <role>: <provider>/<model> <effort> <speed>. Commas separate panel seats. `none` drops the role or seat.
# provider: claudeAgent, codex, grok, antigravity (Gemini). model: an id from orchestrator_capabilities, or latest-sol.
# effort: low, medium, high, xhigh, max. speed: standard, fast (Claude), ultrafast (Codex Sol and Astra).
feature, refactoring: codex/latest-sol high ultrafast
bug-fix: codex/latest-sol high ultrafast
perf-issue: codex/latest-sol high ultrafast
hillclimb: codex/latest-sol high ultrafast
judgment and prose: claudeAgent/claude-opus-5-5 xhigh fast
swarm workers: codex/latest-sol medium ultrafast
arena runners: claudeAgent/claude-fable-5-2 high standard, claudeAgent/claude-opus-5-5 high fast, antigravity/gemini-4-neon xhigh standard, codex/latest-sol high ultrafast
interrogate reviewers: claudeAgent/claude-fable-5-2 high standard, claudeAgent/claude-opus-5-5 high fast, antigravity/gemini-4-neon xhigh standard, codex/latest-sol high ultrafast
one-way door seat: grok/grok-4.7 high standard
arena cross-judge pool: claudeAgent/claude-opus-5-5 high fast, antigravity/gemini-4-neon xhigh standard, codex/latest-sol high ultrafast
