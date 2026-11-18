# pstack in T3 Code

pstack skills use Cursor names. In T3 Code, under Claude, Codex, or Grok, read this file once per session, then map each Cursor name with the tables below. `<pstack>` means the folder that holds `skills/poteto-mode/SKILL.md`. Where this file is silent and the parent is Claude, use `<pstack>/docs/harness/claude-code.md` when it exists. Never pass a field or value the tool schema rejects.

The main difference from plain Claude Code is model routing. Plain Claude Code cannot run a `grok-*` or `gpt-*` slug, so its adapter drops the slug and every "diverse panel" runs on one model. T3 Code can run them with `delegate_task`, so panels stay diverse here.

## Routing a spawn

Pick the target model first (see Roles). Then pick the tool.

| Target | Tool |
| --- | --- |
| Same provider as you, no settings beyond yours, no worktree | Native subagent. Claude: `Agent` with `run_in_background: false`, several in one message for a fan-out. Codex: `spawn_agent`, then wait. Grok: `spawn_subagent`, then `get_command_or_subagent_output`. Grok children run on your model. |
| Another provider, a non-default effort the native tool cannot set, a separate checkout, or work that should outlive your turn | `delegate_task`. |

Before the first `delegate_task` in a thread, call `orchestrator_capabilities` once. Resolve "latest Sol" or any family name from its list. Never guess a model id. If a provider or model is missing or unauthenticated, say so and drop the seat. Do not substitute another model, and do not fall back to a CLI.

`delegate_task` fields: `task` (the whole brief), `role` (`review`, `research`, `implementation`, `design`, `test`, `general`), `mode: "async"`, `target: {providerInstanceId, model, options}`, a fresh `clientRequestId` per spawn. Effort lives in `options`. The key is `effort` for Claude and `reasoningEffort` for Codex and Grok. Keep the returned `taskId`.

## Tools

| Cursor | T3 Code |
| --- | --- |
| `Task` | Routing a spawn, above. |
| `AskQuestion` | Claude: `AskUserQuestion`. Codex: `request_user_input_async` when listed, `request_user_input` in Plan mode. Grok: `ask_user_question`. Otherwise open the final message with the question. |
| Open a todolist | `TodoWrite` in Claude, `update_plan` in Codex, `todo_write` in Grok. Otherwise keep the list in your reply. |
| Run another pstack skill | `Read` `<pstack>/skills/<name>/SKILL.md` and follow it. |
| `/loop`, `drive` or `background` babysit waits, `scripts/watch-pr` polling | `watch_pull_request`, then end your turn. T3 wakes you on a failed check, green required checks, a comment or review, or a conflict. `watch-pr --status-only` is still fine for a one-shot verdict. Call `unwatch_pull_request` before any handoff or question. |
| Waiting on a delegate | Follow its `next`. Never poll `task_status`, never `sleep`, never `Monitor`. Do other work and check each result as it lands. |
| Waiting on your own background command | Claude: `t3_background_wait` with its task id. Codex: the session's own wait for that command. Grok: `get_command_or_subagent_output`. |

## Subagent fields

| Cursor | T3 Code |
| --- | --- |
| `subagent_type: generalPurpose` | Claude native: `general-purpose`. `delegate_task`: no field, the brief carries the role. |
| `poteto-agent` | Same provider under Claude, or under Grok when it loads the Claude plugin: `pstack:poteto-agent`. Otherwise the brief's second line is `Read <abs path>/skills/poteto-mode/SKILL.md in full before any work, including its Principles index.` |
| `comment-sicko` | Same provider under Claude: `pstack:comment-sicko`. Otherwise the brief's first line is `Read <abs path>/agents/comment-sicko.md and act as that agent.` |
| `readonly: true` | There is no read-only switch. Narrow `runtimeMode` values pause for human approval, so never use them for this. Claude native: `Explore`. `delegate_task`: `role: "review"` or `"research"` and the brief opens `Review only. Do not edit, commit, push, comment on PRs, or start subagents.` Run `git status --short` afterward. Do not edit files a reader still reads. |
| `readonly: false` | Default. |
| `environment: "cloud"` | `isolation: "worktree"` on `delegate_task`, or on `Agent` when the worker is Claude. The child starts from your current commit, so commit or copy any uncommitted change it needs. |
| `environment: "local"` | `isolation: "shared"`, the default. |
| `cloud_base_branch: <b>` | A worktree child starts from your current commit, so spawn it while you sit on `<b>`. Never put checkout steps in the brief. |
| `run_in_background: true` | `delegate_task` with `mode: "async"`. A native `Agent` stays foreground. |
| `resume` | A new `delegate_task` with consolidated scope: the original brief, every later directive, and the prior report and branch. Never `t3_thread_send` to a child. `task_cancel` the run you replace. |
| `file_attachments` | List the absolute paths in the brief. |

Every brief, native or `delegate_task`, opens with `Read <abs path>/skills/poteto-mode/worker.md before anything else.` It carries the operator's rules, which load only from a slash command and reach a child no other way. A `delegate_task` child starts with no history. A Codex `spawn_agent` child inherits yours by default, but write the brief as if it did not. Each brief restates the user's goal and names the repo's absolute path, the base SHA, the scope, the checks already run, and the report format. No secrets. Children never call `watch_pull_request` and never start subagents unless the brief says to.

## Roles

Defaults below. Overrides live in `~/.claude/rules/pstack-models.md`, one `<role>: <provider>/<model> <effort>` line per role, such as `swarm workers: codex/gpt-6.1-sol medium`. Claude Code loads that folder on its own. Under Codex, read the file. A list value means one seat per entry. `inherit-parent` or `auto` means your own model, on the native tool.

| pstack role | Default target in T3 |
| --- | --- |
| feature, refactoring, bug-fix, perf-issue, hillclimb | `codex` / latest Sol, `reasoningEffort: high`, `serviceTier: "ultrafast"` |
| judgment and prose | `claudeAgent` / `claude-opus-5-5`, effort `xhigh`, `fastMode: true` |
| swarm workers, verification | `codex` / latest Sol, `reasoningEffort: medium`, `serviceTier: "ultrafast"` |
| arena runners, interrogate reviewers | `claude-fable-5-2 high`, `claude-opus-5-5 high` with `fastMode: true`, and latest Sol `high` on ultrafast. Add `grok` / `grok-4.7 high` as a fourth seat for one-way doors. |
| arena cross-judge pool | `claude-opus-5-5 high` with `fastMode: true`, then latest Sol `high`. The judge's provider must differ from yours. Fable and Opus are both Claude. |

pstack's defaults put code on Opus and use Gemini as a panel seat. T3 has no Gemini, so Codex takes code and the Gemini seat here. Every Codex Sol or Astra child gets `serviceTier: "ultrafast"`, and every Opus 5.5 child gets `fastMode: true`.

Fable 5.2 runs outside a panel only when the user named it for this task, or when two Opus 5.5 `xhigh` runs of the same brief failed its check. Say which. Difficulty alone never qualifies.

Raise a role one step for the hardest work, lower it one step for judgment and two or more for routine work, per poteto-mode's Subagents section. Panel seats keep their listed level. No child runs above `xhigh`.

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
