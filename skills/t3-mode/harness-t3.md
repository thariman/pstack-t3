# pstack in T3 Code

pstack skills use Cursor names. In T3 Code, under Claude or Codex, read this file once per session, then map each Cursor name with the tables below. `<pstack>` means the folder that holds `skills/poteto-mode/SKILL.md`. Where this file is silent and the parent is Claude, use `<pstack>/docs/harness/claude-code.md` when it exists. Never pass a field or value the tool schema rejects.

The main difference from plain Claude Code is model routing. Plain Claude Code cannot run a `grok-*` or `gpt-*` slug, so its adapter drops the slug and every "diverse panel" runs on one model. T3 Code can run them with `delegate_task`, so panels stay diverse here.

## Routing a spawn

Pick the target model first (see Roles). Then pick the tool.

| Target | Tool |
| --- | --- |
| Same provider as you, no settings beyond yours, no worktree | Native subagent. Claude: `Agent` with `run_in_background: false`, several in one message for a fan-out. Codex: `spawn_agent`, then wait. |
| Another provider, a non-default effort the native tool cannot set, a separate checkout, or work that should outlive your turn | `delegate_task`. |

Before the first `delegate_task` in a thread, call `orchestrator_capabilities` once. Resolve "latest Sol" or any family name from its list. Never guess a model id. If a provider or model is missing or unauthenticated, say so and drop the seat. Do not substitute another model, and do not fall back to a CLI.

`delegate_task` fields: `task` (the whole brief), `role` (`review`, `research`, `implementation`, `design`, `test`, `general`), `mode: "async"`, `target: {providerInstanceId, model, options}`, a fresh `clientRequestId` per spawn. Effort lives in `options`. The key is `effort` for Claude and `reasoningEffort` for Codex and Grok. Keep the returned `taskId`.

## Tools

| Cursor | T3 Code |
| --- | --- |
| `Task` | Routing a spawn, above. |
| `AskQuestion` | Claude: `AskUserQuestion`. Codex: `request_user_input_async` when listed, `request_user_input` in Plan mode. Otherwise open the final message with the question. |
| Open a todolist | `TodoWrite` in Claude, `update_plan` in Codex. Otherwise keep the list in your reply. |
| Run another pstack skill | `Read` `<pstack>/skills/<name>/SKILL.md` and follow it. |
| `/loop`, `drive` or `background` babysit waits, `scripts/watch-pr` polling | `watch_pull_request`, then end your turn. T3 wakes you on a failed check, green required checks, a comment or review, or a conflict. `watch-pr --status-only` is still fine for a one-shot verdict. Call `unwatch_pull_request` before any handoff or question. |
| Waiting on a delegate | Follow its `next`. Never poll `task_status`, never `sleep`, never `Monitor`. Do other work and check each result as it lands. |
| Waiting on your own background command | Claude: `t3_background_wait` with its task id. Codex: the session's own wait for that command. |

## Subagent fields

| Cursor | T3 Code |
| --- | --- |
| `subagent_type: generalPurpose` | Claude native: `general-purpose`. `delegate_task`: no field, the brief carries the role. |
| `poteto-agent` | Same provider under Claude: `pstack:poteto-agent`. Otherwise the brief's first line is `Read <abs path>/skills/poteto-mode/SKILL.md in full before any work, including its Principles index.` |
| `comment-sicko` | Same provider under Claude: `pstack:comment-sicko`. Otherwise the brief's first line is `Read <abs path>/agents/comment-sicko.md and act as that agent.` |
| `readonly: true` | There is no read-only switch. Narrow `runtimeMode` values pause for human approval, so never use them for this. Claude native: `Explore`. `delegate_task`: `role: "review"` or `"research"` and the brief opens `Review only. Do not edit, commit, push, comment on PRs, or start subagents.` Run `git status --short` afterward. Do not edit files a reader still reads. |
| `readonly: false` | Default. |
| `environment: "cloud"` | `isolation: "worktree"` on `delegate_task`, or on `Agent` when the worker is Claude. The child starts from your current commit, so commit or copy any uncommitted change it needs. |
| `environment: "local"` | `isolation: "shared"`, the default. |
| `cloud_base_branch: <b>` | A worktree child starts from your current commit, so spawn it while you sit on `<b>`. Never put checkout steps in the brief. |
| `run_in_background: true` | `delegate_task` with `mode: "async"`. A native `Agent` stays foreground. |
| `resume` | A new `delegate_task` with consolidated scope: the original brief, every later directive, and the prior report and branch. Never `t3_thread_send` to a child. `task_cancel` the run you replace. |
| `file_attachments` | List the absolute paths in the brief. |

A `delegate_task` child starts with no history. A Codex `spawn_agent` child inherits yours by default, but write the brief as if it did not. Each brief restates the user's goal and names the repo's absolute path, the base SHA, the scope, the checks already run, and the report format. No secrets. Children never call `watch_pull_request` and never start subagents unless the brief says to.

## Roles

Defaults below. Overrides live in `~/.claude/rules/pstack-models.md`, one `<role>: <provider>/<model> <effort>` line per role, such as `swarm workers: codex/gpt-6.1-sol medium`. Claude Code loads that folder on its own. Under Codex, read the file. A list value means one seat per entry. `inherit-parent` or `auto` means your own model, on the native tool.

| pstack role | Default target in T3 |
| --- | --- |
| judgment and prose, hardest tasks, how explainer, why synthesizer, reflect judgment | `claudeAgent` / `claude-opus-5-5`, effort `xhigh` |
| feature, refactoring, bug-fix, perf-issue, hillclimb | `codex` / latest Sol, `reasoningEffort: high` |
| swarm workers, how explorer, why investigators, reflect tooling | `codex` / latest Sol, `reasoningEffort: medium` |
| arena runners, architect runners, interrogate reviewers | `claude-opus-5-5 xhigh` and latest Sol `xhigh`. Add `grok` / `grok-4.7 xhigh` as a third seat for one-way doors. |
| arena cross-judge pool | Latest Sol `xhigh`, then `claude-opus-5-5 xhigh`. The judge's provider must differ from yours. |

pstack's `grok-*` defaults map to Codex here. Name Grok in the overrides file to get it back. Raise effort one step for the hardest work and lower it for routine work, per poteto-mode's Subagents section. Use a fast tier (`fastMode` for Claude, `serviceTier: "priority"` for Codex) only when trunk is red or a person is blocked now.

## Cursor-only features

When a step needs one of these, write one line, `Skipped in T3 Code: <step>. <reason>.`, and go on.

| Cursor | T3 Code |
| --- | --- |
| Cursor Automations, `SendToUser` secret requests | Skip. For a secret only the user has, call `request_secret`. For a scheduled run, `schedule_task` covers it. |
| Bugbot | Its PR comments are ordinary review threads. Skip steps that start or configure it. |
| Cursor cloud agents | Use `isolation: "worktree"`. Skip steps that need the cloud dashboard. |
| Origin | Use `gh`. |
| `~/.cursor/rules/pstack-models.mdc` | `~/.claude/rules/pstack-models.md`, see Roles. |
| `~/.cursor/plugins/` | `~/.claude/plugins/` under Claude, `~/.codex/skills/` under Codex. |
| A PR you open or push | Link it with `link_pull_request` as your next call. |
