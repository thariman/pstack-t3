# pstack in T3 Code

pstack skills use Cursor names. In T3 Code, under Claude, Codex, Grok, or Antigravity, read this file once per session, then map each Cursor name with the tables below. `<pstack>` means the folder that holds `skills/poteto-mode/SKILL.md`. Where this file is silent and the parent is Claude, use `<pstack>/docs/harness/claude-code.md` when it exists. Never pass a field or value the tool schema rejects.

The main difference from plain Claude Code is model routing. Plain Claude Code cannot run a `grok-*` or `gpt-*` slug, so its adapter drops the slug and every "diverse panel" runs on one model. T3 Code can run them with `delegate_task`, so panels stay diverse here.

## Routing a spawn

Before you resolve the first seat in a thread, call `orchestrator_capabilities` once and reuse its result. Resolve the target model and options first (see Roles). Then pick the tool.

| Target | Tool |
| --- | --- |
| Same provider as you, a model and options your native tool can set exactly, no worktree | Native subagent. Claude: `Agent` with `run_in_background: false`, several in one message for a fan-out. Codex: `spawn_agent`, then wait. Grok: `spawn_subagent`, then `get_command_or_subagent_output`. Grok children run on your model. Antigravity: `invoke_subagent` with `Model: "inherit"`. It has no wait tool, and the result arrives as a message, so end your turn or do other work until it does. |
| Another provider, a non-default effort the native tool cannot set, a separate checkout, or work that should outlive your turn | `delegate_task`. |

Resolve "latest Sol" or any family name from its list. Never guess a model id. When a provider or model is missing, follow **Use what this machine has** under Roles. Never fall back to a CLI.

`delegate_task` fields: `task` (the whole brief), `role` (`review`, `research`, `implementation`, `design`, `test`, `general`), `mode: "async"`, `target: {providerInstanceId, model, options}`, a fresh `clientRequestId` per spawn. Effort lives in `options`. The key is `effort` for Claude, `reasoningEffort` for Codex and Grok, and `thought_level` for Antigravity. Keep the returned `taskId`.

## Tools

| Cursor | T3 Code |
| --- | --- |
| `Task` | Routing a spawn, above. |
| `AskQuestion` | Claude: `AskUserQuestion`. Codex: `request_user_input_async` when listed, `request_user_input` in Plan mode. Grok: `ask_user_question`. Antigravity: `ask_question`. Otherwise open the final message with the question. |
| Open a todolist | `TodoWrite` in Claude, `update_plan` in Codex, `todo_write` in Grok, `update_steps` in Antigravity. Otherwise keep the list in your reply. |
| Run another pstack skill | `Read` `<pstack>/skills/<name>/SKILL.md` and follow it. |
| `/loop`, `drive` or `background` babysit waits, `scripts/watch-pr` polling | `watch_pull_request`, then end your turn. T3 wakes you on a failed check, green required checks, a comment or review, or a conflict. `watch-pr --status-only` is still fine for a one-shot verdict. Call `unwatch_pull_request` before any handoff or question. |
| Waiting on a delegate | Follow its `next`. Never poll `task_status`, never `sleep`, never `Monitor`. Do other work and check each result as it lands. |
| Waiting on your own background command | Claude: `t3_background_wait` with its task id. Codex: the session's own wait for that command. Grok: `get_command_or_subagent_output`. Antigravity: `run_command` notifies you when the command ends, so do other work until then. |

## Subagent fields

| Cursor | T3 Code |
| --- | --- |
| `subagent_type: generalPurpose` | Claude native: `general-purpose`. `delegate_task`: no field, the brief carries the role. |
| `poteto-agent` | Same provider under Claude, or under Grok when it loads the Claude plugin: `pstack:poteto-agent`. Otherwise, including Antigravity, the brief's second line is `Read <abs path>/skills/poteto-mode/SKILL.md in full before any work, including its Principles index.` |
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

Each child's model, effort, and speed come from a profile. Read `profiles/default.md` next to this file, then `~/.config/pstack-t3/active.md` if it exists. A role line in the active profile replaces the default's line, and a role it leaves out keeps the default. When the user names a profile in the task, such as `/t3-mode profile=budget`, read `~/.config/pstack-t3/profiles/<name>.md` or `profiles/<name>.md` instead of the active one, for this task only. In `t3-mode`, the profile replaces `~/.claude/rules/pstack-models.md`. Ignore that file's lines.

A line is `<roles>: <seats>`. Split it at the first colon. On the left, commas separate role names that share the line. On the right, commas separate seats, one child per seat, each `<provider>/<model> <effort> <speed>`. `none` drops the role or seat, and a dropped cross-judge means arena picks its base alone and says so.

- `provider` is the `providerInstanceId`. `latest-sol` means the newest Sol id that `orchestrator_capabilities` lists.
- `effort` goes in `options` as `effort` for `claudeAgent`, `reasoningEffort` for `codex` and `grok`, and `thought_level` for `antigravity`.
- `speed` `fast` is `fastMode: true`, `ultrafast` is `serviceTier: "ultrafast"`, and `standard` is `fastMode: false` for Claude and `serviceTier: "default"` for Codex, set explicitly because Sol can default to ultrafast.
- `one-way door seat` is appended to every arena and interrogate panel on a decision that is hard to reverse, before missing seats are resolved, and follows the same rules as the other seats.
- Trivial mechanical edits and verification use `swarm workers`.

pstack's own defaults put code on Opus. The default profile gives code to Codex Sol and adds Sol as a fourth panel seat next to pstack's Fable, Opus, and Gemini. Fable 5.2 runs outside a panel only when the user named it for this task, the profile puts it on that role, or two Opus 5.5 `xhigh` runs of the same brief failed its check. Say which. Difficulty alone never qualifies.

**Use what this machine has.** Machines differ in which providers T3 can run. A target is runnable when its provider reports `canRunChildTask: true` and no constraints, also `canRunCrossProviderChildTask: true` when it is not your provider, and lists the model. When a model is missing and the provider reports omitted models, call `orchestrator_capabilities` with `search` before you call it missing. `latest-sol` is the highest-numbered Sol id on `codex`. The user asked `t3-mode` to fill a gap instead of dropping work, so for each seat that is not runnable:

1. Try the fallback order, skipping targets that are not runnable: `codex` / latest Sol, `claudeAgent` / `claude-opus-5-5`, `antigravity` / `gemini-4-neon`, `grok` / `grok-4.7`.
2. A one-seat role takes the first runnable target. With none, do the work yourself and say so.
3. A panel keeps every runnable seat and replaces each missing seat, in profile order, with the first runnable target whose provider is not on the panel yet, then one whose model is not on it yet, then any runnable target. Each replacement is its own child. Print `Seat dropped: <seat>, nothing here can run it.` only when no target runs.
4. The cross-judge takes the first runnable pool entry whose `providerInstanceId` differs from yours, with that entry's effort and speed. With none, it takes the first runnable fallback target on another provider at `high` and standard speed. With none, arena picks its base alone and says so.
5. A moved seat keeps its effort when the substitute lists it, or takes the highest listed effort below it. A fast speed maps to `fastMode: true` on Opus 5.5 and `serviceTier: "ultrafast"` on Codex Sol and Astra. Every other case is standard speed, set explicitly where the model offers it: `fastMode: false` for Claude, `serviceTier: "default"` for Codex.

Print one line per seat whose target changed, with role, old target, new target, effort, and speed, such as `Seat moved: arena runners, grok/grok-4.7 is not available here, using antigravity/gemini-4-neon high standard.` Never move a seat silently.

A panel seat runs at its profile effort. For any other role, the profile effort is the ceiling. Use it for the hardest work, one step below for judgment, and two or more below for routine work, per poteto-mode's Subagents section. Go above the profile only when the user asks.

## Cursor-only features

When a step needs one of these, write one line, `Skipped in T3 Code: <step>. <reason>.`, and go on.

| Cursor | T3 Code |
| --- | --- |
| Cursor Automations, `SendToUser` secret requests | Skip. For a secret only the user has, call `request_secret`. For a scheduled run, `schedule_task` covers it. |
| Bugbot | Its PR comments are ordinary review threads. Skip steps that start or configure it. |
| Cursor cloud agents | Use `isolation: "worktree"`. Skip steps that need the cloud dashboard. |
| Origin | Use `gh`. |
| `~/.cursor/rules/pstack-models.mdc`, `/setup-pstack` | The active profile, see Roles. Change it with `profile.sh` in the pstack-t3 repo. |
| `~/.cursor/plugins/` | `~/.claude/plugins/` under Claude, `~/.codex/skills/` under Codex. |
| A PR you open or push | Link it with `link_pull_request` as your next call. |
