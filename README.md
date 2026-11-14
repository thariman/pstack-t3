# pstack-t3

`pstack-t3` runs [pstack](https://github.com/cursor/plugins/tree/main/pstack)'s `poteto-mode` inside [T3 Code](https://github.com/pingdotgg/t3code), with Claude, Codex, and Grok as the main agent. Its multi-model reviews run on real Claude, Codex, and Grok models through T3's `delegate_task`, instead of collapsing onto one model.

It does not copy pstack. It adds one skill, `t3-mode`, that loads pstack and a translation table for T3. pstack updates reach you without a re-port.

## Install or update on any machine

You need `git`, `curl`, and at least one of `claude`, `codex`, or `grok`.

Run this command. It works for the first install and for every update after.

```bash
[ -d ~/.local/share/pstack-t3 ] || git clone https://github.com/thariman/pstack-t3 ~/.local/share/pstack-t3; ~/.local/share/pstack-t3/install.sh
```

A healthy run ends with one version line per harness and the drift check.

```text
upstream: pstack 0.15.36
claude: pstack 0.15.36
codex: pstack 0.15.36
grok: pstack 0.15.36
ok: every Cursor name pstack uses is mapped (...)
```

If a line ends in `STALE`, that harness is behind upstream. Rerun the installer. If you see `pstack update failed (claude): <reason>`, Claude's plugin update failed and the rest of the install still ran. If you see `skip <path>: a real folder is there`, the installer refused to overwrite a folder it did not create. Remove the folder and rerun.

Restart open Claude sessions after an update. `claude plugin update` applies on the next start.

## Use it

Type `/t3-mode <task>` in a Claude or Grok thread, or `$t3-mode <task>` in Codex. The agent finds pstack, reads `harness-t3.md`, then runs `poteto-mode` on your task.

Retype `/t3-mode` at the start of each new task in a thread. The instructions stay in the thread's history, but agents follow them less closely as the thread grows, and long threads get summarized. A new thread always needs it again.

Typing `/pstack:poteto-mode` alone skips the translation table. The agent then guesses at Cursor names, and in Claude every multi-model panel runs on Claude.

## What the installer does

| Harness | pstack missing | pstack present |
| --- | --- | --- |
| Claude | Adds the `cursor-plugins` marketplace and installs `pstack@cursor-plugins`. | Runs `claude plugin marketplace update cursor-plugins`, then `claude plugin update pstack@cursor-plugins`, and shows the result. |
| Codex | Clones `cursor/plugins` to `~/.local/share/cursor-plugins` and links `~/.codex/skills/pstack` to it. | Pulls that clone. |
| Grok, with Claude installed | Nothing. Grok reads `~/.claude/skills` and Claude's installed plugins. | Updated through Claude. |
| Grok, without Claude | Same as Codex, with `~/.grok/skills/pstack`. | Pulls the clone. |

It also links `t3-mode` into `~/.claude/skills`, `~/.codex/skills`, and, on machines without Claude, `~/.grok/skills`.

If a real pstack folder sits in `~/.codex/skills`, `~/.agents/skills`, or `~/.grok/skills`, the installer moves it to `~/.local/share/pstack-t3/backups/<harness>-<folder>-pstack-<timestamp>` and links the managed clone in its place. The backup lives outside every skills folder, so no harness loads pstack twice.

The installer pulls this repo first. If the pull brings a newer `install.sh`, it prints `updated pstack-t3 to <commit>, restarting the installer` and runs the new version once.

Every step is safe to rerun.

## Files

| File | Purpose |
| --- | --- |
| `skills/t3-mode/SKILL.md` | Entry skill. Finds pstack, loads `harness-t3.md`, runs `poteto-mode`. |
| `skills/t3-mode/harness-t3.md` | Maps each Cursor name in pstack to its T3 equivalent for Claude, Codex, and Grok. Holds the model role defaults. |
| `skills/t3-mode/agents/openai.yaml` | Display name and default prompt for Codex. |
| `install.sh` | Installs and updates everything on one machine. |
| `check.sh` | Fails when pstack uses a Cursor subagent field that `harness-t3.md` does not map. Takes an optional pstack path. |
| `test-install.sh` | Runs `install.sh` in throwaway home folders with stub binaries. Covers takeover, rerun, a failed Claude update, Grok inheritance, offline upstream, and the self-update restart. |

## Model roles

`harness-t3.md` assigns these defaults. pstack's own defaults use Grok for code. Here Codex takes that job.

| Role | Default |
| --- | --- |
| Judgment, prose, and the hardest code | Claude `claude-opus-5-5`, effort `xhigh` |
| Feature, refactoring, bug fix, and perf work | Codex latest Sol, `reasoningEffort: high` |
| Swarm workers and explorers | Codex latest Sol, `reasoningEffort: medium` |
| Arena, architect, and interrogate panels | Opus 5.5 and latest Sol, with Grok 4.7 as a third seat for decisions that are hard to reverse |
| Cross-judge | A model from a provider other than the main agent's |

To override a role, add a line such as `swarm workers: codex/gpt-6.1-sol medium` to `~/.claude/rules/pstack-models.md`. Claude loads that folder on its own. Codex and Grok agents read the file when `harness-t3.md` tells them to.

## Why it is built this way

**Plain Claude Code loses pstack's model mix.** pstack is written for Cursor. Its Claude Code adapter, `docs/harness/claude-code.md`, tells the agent to drop any `grok-*` or `gpt-*` model and run on the session model. Every arena, interrogate, and cross-judge panel then becomes Claude reviewing Claude. T3's `delegate_task` can start Codex and Grok children, so the panels keep their mix.

**An adapter outlives a fork.** pstack has about 60 skills and 23 playbooks and ships often. The plugin cache on the first machine held 0.15.29 and 0.15.36 a week apart. pstack already supports other harnesses through a translation table instead of copies. `harness-t3.md` follows that pattern, and `check.sh` catches the day pstack adds a field the table does not cover.

**T3 has rules that Cursor and plain Claude Code do not.** Each rule below changed a row in `harness-t3.md`.

- T3 has no read-only switch for children. The narrower runtime modes pause for human approval. Reviewer briefs say "Review only" and the parent checks `git status` afterward.
- A worktree child starts from the parent's current commit. Checkout steps never go in a brief.
- A `delegate_task` child starts with no history, so every brief stands alone. A Codex `spawn_agent` child inherits history by default.
- A parent never polls a delegate. It follows the delegate's `next` and does other work meanwhile.
- Each review round is a fresh `delegate_task`, never a message to an old child.
- Only the thread that owns a PR calls `watch_pull_request`. It calls `unwatch_pull_request` before any handoff.

**Each harness names its tools differently.** Live children inside T3 confirmed these names. Two of them corrected names copied from Grok's README, which documents a different route.

| Job | Claude | Codex | Grok |
| --- | --- | --- | --- |
| Start a same-provider helper | `Agent` | `spawn_agent` | `spawn_subagent` |
| Wait for it | Returns in the same turn | `wait_agent` | `get_command_or_subagent_output` |
| Todo list | `TodoWrite` | `update_plan` | `todo_write` |
| Ask the user | `AskUserQuestion` | `request_user_input_async`, or `request_user_input` in Plan mode | `ask_user_question` |

**Grok needed almost nothing.** Grok reads `~/.claude/skills` and Claude's installed plugins, including pstack's `poteto-agent`. On a machine without Claude, a pstack link in `~/.grok/skills` works. A link in `~/.grok/plugins` did not load.

## What is proven

These ran on real machines, not only in tests.

| Machine | OS | Result |
| --- | --- | --- |
| Desktop | Linux | Update path and takeover of a stray Codex copy. All harnesses at 0.15.36. |
| Laptop | Linux | Update path. All harnesses at 0.15.36. |
| MacBook | macOS | First install for Claude and Codex. Passed under Homebrew bash 5.2 and under `/bin/bash` 3.2. |

The self-update restart worked against real git in a throwaway repo. It has not yet run on a real machine. A real Claude update failure has only been simulated.

## Known limits

- **The rules run on the honor system.** `t3-mode` is instructions. Nothing checks that an agent restated the goal, listed the playbook steps, or used a second model for review. The planned fix is a transcript grader, then a Claude `Stop` hook for any model that misses often. It is not built.
- **Updates do not happen on launch.** Claude's auto-update for the `cursor-plugins` marketplace is off by default. Turn it on in `/plugin`, on the Marketplaces tab. Grok then follows Claude. Codex never updates on launch. Only `install.sh` updates it. A daily timer is planned and not built.
- **Claude installs pstack over SSH on some machines.** On the MacBook, `claude plugin marketplace add` cloned `git@github.com:cursor/plugins.git`. A machine without a GitHub SSH key can fail at that step.
- **`check.sh` runs under the first `bash` on `PATH`**, not under the `bash` that runs `install.sh`.

## Sources

- **pstack** by Lauren Tan (poteto), MIT license, from [cursor/plugins](https://github.com/cursor/plugins/tree/main/pstack). Built against version 0.15.36, commit `3dbd22f`. `harness-t3.md` follows the structure of pstack's `docs/harness/claude-code.md`.
- **tstack** by Theo Browne, MIT license, from [t3dotgg/tstack](https://github.com/t3dotgg/tstack). No tstack skill is installed or called. These rules in `harness-t3.md` come from its skills.

| Rule | tstack skill |
| --- | --- |
| Call `orchestrator_capabilities` once and resolve the latest Sol instead of a fixed model id | `sol-loop` |
| If a model is unavailable, drop the seat and say so. Never substitute | `council`, `sol-loop` |
| Each review round is a fresh `delegate_task` with a new `clientRequestId` | `sol-loop` |
| Wait with `watch_pull_request`, unwatch before handoff, children never watch | `babysit-pr`, `full-send` |

Two tstack skills cover jobs pstack has no playbook for. `modernize` decides whether an old PR should be rebased, reworked, or closed. `leaving-pr-comments` labels agent-written PR comments. They are candidates to add.

`github.com/tstack` is Tim Stack's account, the author of lnav. It is unrelated to agent skills.

## License

MIT. See `LICENSE`.

## Develop

Run both checks before you push.

```bash
./check.sh
./test-install.sh
```

`check.sh` with no argument checks the newest installed pstack. Pass a path to check another copy, such as `./check.sh ~/.codex/skills/pstack`.
