# pstack-t3

`pstack-t3` runs [pstack](https://github.com/cursor/plugins/tree/main/pstack)'s `poteto-mode` inside [T3 Code](https://github.com/pingdotgg/t3code), with Claude, Codex, Grok, or Antigravity as the main agent. Its multi-model reviews run on real Claude, Codex, Gemini, and Grok models through T3's `delegate_task`, instead of collapsing onto one model.

It does not copy pstack. It adds one skill, `t3-mode`, that loads pstack, a translation table for T3, and a model profile. pstack updates reach you without a re-port, and the installer holds back any update that does not match `t3-mode` yet.

## Install or update on any machine

You need `git`, `curl`, and at least one of `claude`, `codex`, `grok`, or `agy` (Antigravity).

Run this command. It works for the first install and for every update after.

```bash
[ -d ~/.local/share/pstack-t3 ] || git clone https://github.com/thariman/pstack-t3 ~/.local/share/pstack-t3; ~/.local/share/pstack-t3/install.sh
```

On a machine where you keep your own clone, such as `~/projects/pstack-t3`, run that clone's `install.sh` instead. The links then point at your clone.

The first line names the harnesses the installer found. It installs only for those and skips the rest. A healthy run ends with one version line per harness it found and the drift check.

```text
harnesses on this machine: claude codex grok agy
...
upstream: pstack 0.15.48
claude: pstack 0.15.48
codex: pstack 0.15.48
grok: pstack 0.15.48
agy: pstack 0.15.48
ok: every Cursor name, file, and role t3-mode uses matches pstack (...)
```

If a line ends in `STALE`, that harness is behind upstream. Rerun the installer.

The installer checks every new pstack before it installs it. If the check fails, you see `pstack update held (<harness>): ...` with the reasons, and that harness keeps the pstack it has. Nothing breaks. The daily job below opens a pull request that fixes `t3-mode`, and the update goes through on the first install after you merge it.

If you see `review: since pstack <version>, pstack changed <files>`, the new pstack passed the check but changed files `t3-mode` follows closely. It is installed. Someone should read those changes, and the daily job does that for you. If you see `pstack update failed (claude): <reason>`, Claude's plugin update failed and the rest of the install still ran. If you see `skip <path>: a real folder is there`, the installer refused to overwrite a folder it did not create. Remove the folder and rerun.

Restart open Claude sessions after an update. `claude plugin update` applies on the next start.

## Use it

Type `/t3-mode <task>` in a Claude, Grok, or Antigravity thread, or `$t3-mode <task>` in Codex. The agent finds pstack, reads `harness-t3.md`, then runs `poteto-mode` on your task.

Retype `/t3-mode` at the start of each new task in a thread. The instructions stay in the thread's history, but agents follow them less closely as the thread grows, and long threads get summarized. A new thread always needs it again.

Typing `/pstack:poteto-mode` alone skips the translation table. The agent then guesses at Cursor names, and in Claude every multi-model panel runs on Claude.

## What the installer does

| Harness | pstack missing | pstack present |
| --- | --- | --- |
| Claude | Adds the `cursor-plugins` marketplace and installs `pstack@cursor-plugins`. | Runs `claude plugin marketplace update cursor-plugins`, checks the downloaded pstack, and runs `claude plugin update pstack@cursor-plugins` only if the check passes. |
| Codex | Clones `cursor/plugins` to `~/.local/share/cursor-plugins` and links `~/.codex/skills/pstack` to it. | Pulls that clone and checks it. If the check fails, it moves the clone back to the commit it had. |
| Grok, with Claude installed | Nothing. Grok reads `~/.claude/skills` and Claude's installed plugins. | Updated through Claude. |
| Grok, without Claude | Same as Codex, with `~/.grok/skills/pstack`. | Same as Codex. |
| Antigravity | Uses the same managed clone as Codex, and writes `~/.gemini/config/skills.json` to list this repo's `skills` folder and the clone's `pstack/skills`. | Same as Codex. Leaves a `skills.json` it did not write alone and prints the two entries to add. |

A harness counts as installed when its command is on `PATH`. Antigravity also counts when T3 Code ships its own copy in `~/.t3/userdata/providers/antigravity`, which reads the same `skills.json`.

It also links `t3-mode` into `~/.claude/skills`, `~/.codex/skills`, and, on machines without Claude, `~/.grok/skills`.

If a real pstack folder sits in `~/.codex/skills`, `~/.agents/skills`, or `~/.grok/skills`, the installer moves it to `~/.local/share/pstack-t3-backups/<harness>-<folder>-pstack-<timestamp>` and links the managed clone in its place. The backup lives outside every skills folder, so no harness loads pstack twice. When the managed clone fails the check, the installer leaves your folder where it is and prints `kept <harness>'s own pstack folder`.

The installer pulls this repo first. If the pull brings a newer `install.sh`, it prints `updated pstack-t3 to <commit>, restarting the installer` and runs the new version once.

Every step is safe to rerun.

## Files

| File | Purpose |
| --- | --- |
| `skills/t3-mode/SKILL.md` | Entry skill. Finds pstack, loads `harness-t3.md`, runs `poteto-mode`. |
| `skills/t3-mode/harness-t3.md` | Maps each Cursor name in pstack to its T3 equivalent for Claude, Codex, and Grok, and says how to read a profile. |
| `skills/t3-mode/agents/openai.yaml` | Display name and default prompt for Codex. |
| `install.sh` | Installs and updates everything on one machine. |
| `skills/t3-mode/profiles/` | Built-in model profiles. `default.md` holds every role's default. |
| `profile.sh` | Lists, shows, switches, and checks profiles. |
| `check.sh` | Fails when pstack uses a Cursor subagent field that `harness-t3.md` does not map, drops a file `t3-mode` reads, or adds or removes a model role. Takes an optional pstack path. `--record` marks a pstack as read and verified. |
| `pstack-verified.txt` | The last pstack read and verified by hand, with checksums of the files `t3-mode` follows closely. |
| `test-install.sh` | Runs `install.sh` in throwaway home folders with stub binaries and a local git repo standing in for upstream. Covers harness detection, takeover, rerun, a failed Claude update, updates held for Claude and Codex, a working folder kept when upstream fails the check, Grok inheritance, offline upstream, the self-update restart, the `review:` notice, profiles, and this README's version lines and file list. |
| `upstream-job.md` | The brief the daily upstream job runs. |
| `LICENSE` | MIT. |
| `CREDITS.md` | Who made pstack, tstack, and T3 Code, and what this repo uses from each. |

## Model profiles

A profile sets the model, effort, and speed for every pstack role. `t3-mode` reads the default profile, then the active one on top of it.

| Profile | For |
| --- | --- |
| `default` | Code on Codex Sol, judgment on Opus 5.5, panels of Fable 5.2, Opus 5.5, Gemini 4 Neon, and Sol, and Grok 4.7 added for decisions that are hard to reverse. |
| `budget` | Lower effort, two-seat panels of Opus and Sol, no Fable, Gemini, or Grok. |
| `deep` | `xhigh` everywhere, Fable 5.2 for judgment, and Gemini and Grok on every panel. |
| `claude-only` | Every child on Claude. Arena has no cross-vendor judge. |

```bash
~/.local/share/pstack-t3/profile.sh               # list profiles, * marks the active one
~/.local/share/pstack-t3/profile.sh show          # every role with its model, effort, and speed
~/.local/share/pstack-t3/profile.sh show deep     # the same for another profile
~/.local/share/pstack-t3/profile.sh use budget    # switch this machine
```

The active profile is a link at `~/.config/pstack-t3/active.md`, one per machine. To use a profile for one task only, write it in the prompt, as in `/t3-mode profile=deep <task>`.

To make your own, copy a profile into `~/.config/pstack-t3/profiles/` and edit it. A role you leave out keeps the default's line. `use` refuses a profile with a mistake in it, and `profile.sh check` lists the mistakes.

```text
# <role>: <provider>/<model> <effort> <speed>, commas between panel seats, `none` to drop
bug-fix: codex/latest-sol xhigh ultrafast
arena runners: claudeAgent/claude-opus-5-5 high fast, codex/latest-sol high ultrafast
```

Providers are `claudeAgent`, `codex`, `grok`, and `antigravity` for Gemini. A model is any id `orchestrator_capabilities` lists, or `latest-sol`. Effort is `low` through `max`. Speed is `standard`, `fast` (Claude only), or `ultrafast` (Codex Sol and Astra only).

Profiles name providers a machine may not have. At run time `t3-mode` asks T3 which providers can run, and moves each seat on a missing provider to the first available one in the order Codex Sol, Opus 5.5, Gemini 4 Neon, Grok 4.7. A panel replaces a missing seat with a provider it does not have yet, and drops a seat only when nothing on the machine can run it. Each move is printed, as in `Seat moved: arena runners, grok/grok-4.7 is not available here, using antigravity/gemini-4-neon high standard.` So one profile works on every machine.

`t3-mode` ignores pstack's own `/setup-pstack` file, `~/.claude/rules/pstack-models.md`. Change models with a profile instead.

## Why it is built this way

**Plain Claude Code loses pstack's model mix.** pstack is written for Cursor. Its Claude Code adapter, `docs/harness/claude-code.md`, tells the agent to drop any `grok-*` or `gpt-*` model and run on the session model. Every arena, interrogate, and cross-judge panel then becomes Claude reviewing Claude. T3's `delegate_task` can start Codex, Gemini, and Grok children, so the panels keep their mix. Gemini 4 Neon runs through T3's `antigravity` provider.

**An adapter outlives a fork.** pstack has about 60 skills and 23 playbooks and ships often. The plugin cache on the first machine held 0.15.29 and 0.15.36 a week apart. pstack already supports other harnesses through a translation table instead of copies. `harness-t3.md` follows that pattern, and `check.sh` catches the day pstack adds a field the table does not cover, drops a file `t3-mode` reads, or changes its model roles.

**Gate updates instead of pinning a version.** pstack went from 0.15.36 to 0.15.48 in eleven days. A pin goes stale within days and gives no signal about which update is safe, and Claude's plugin commands cannot pin a version. The installer instead checks each new pstack and keeps the current one when the check fails. The checks passed on 0.15.42 and 0.15.43 while real drift slipped through: retired roles and the new `worker.md` rule. So `check.sh` now also checks files and roles, and the daily job sends wording changes to a model for review.

**The fix comes as a pull request, not from each machine.** An agent inside the installer would write a different, unreviewed fix on every machine. One scheduled job writes one fix, gets a review from another vendor's model, and waits for your merge.

**T3 has rules that Cursor and plain Claude Code do not.** Each rule below changed a row in `harness-t3.md`.

- T3 has no read-only switch for children. The narrower runtime modes pause for human approval. Reviewer briefs say "Review only" and the parent checks `git status` afterward.
- A worktree child starts from the parent's current commit. Checkout steps never go in a brief.
- A `delegate_task` child starts with no history, so every brief stands alone. A Codex `spawn_agent` child inherits history by default.
- A parent never polls a delegate. It follows the delegate's `next` and does other work meanwhile.
- Each review round is a fresh `delegate_task`, never a message to an old child.
- Only the thread that owns a PR calls `watch_pull_request`. It calls `unwatch_pull_request` before any handoff.

**Each harness names its tools differently.** Live children inside T3 confirmed these names. Two of them corrected names copied from Grok's README, which documents a different route.

| Job | Claude | Codex | Grok | Antigravity |
| --- | --- | --- | --- | --- |
| Start a same-provider helper | `Agent` | `spawn_agent` | `spawn_subagent` | `invoke_subagent` |
| Wait for it | Returns in the same turn | `wait_agent` | `get_command_or_subagent_output` | No wait tool. The result arrives as a message |
| Todo list | `TodoWrite` | `update_plan` | `todo_write` | `update_steps` |
| Ask the user | `AskUserQuestion` | `request_user_input_async`, or `request_user_input` in Plan mode | `ask_user_question` | `ask_question` |

**Antigravity reads skills from its own list.** It never looks in `~/.claude/skills`, `~/.codex/skills`, or `~/.agents/skills`. It loads global skills only from `~/.gemini/config/skills/` or from folders named in `~/.gemini/config/skills.json`, so the installer writes that file instead of linking. Its skill list hides `poteto-mode`, because pstack marks it `disable-model-invocation`. That does not matter, because `t3-mode` reads `poteto-mode` by path.

**Grok needed almost nothing.** Grok reads `~/.claude/skills` and Claude's installed plugins, including pstack's `poteto-agent`. On a machine without Claude, a pstack link in `~/.grok/skills` works. A link in `~/.grok/plugins` did not load.

## What is proven

These ran on real machines, not only in tests.

| Machine | OS | Result |
| --- | --- | --- |
| Desktop | Linux | Update path and takeover of a stray Codex copy. Updated through 0.15.43 on 2026-11-18. A Gemini 4 Neon child answered through `antigravity` on 2026-11-25. The same day, an Antigravity thread ran `/t3-mode` on a read-only question. It found pstack 0.15.48, read `harness-t3.md`, `poteto-mode`, and the Investigation playbook, and named the right Antigravity tools. |
| Laptop | Linux | Update path. All harnesses at 0.15.36 on 2026-11-14. On 2026-11-25 it found all four harnesses, all at 0.15.48 with Antigravity's `skills.json` in place, and a rerun changed nothing. |
| MacBook | macOS | First install for Claude and Codex, at 0.15.36 on 2026-11-14. Passed under Homebrew bash 5.2 and under `/bin/bash` 3.2. On 2026-11-25 it found all four harnesses, gated and installed 0.15.48 for each, and wrote Antigravity's `skills.json`. A rerun changed nothing. A run under `/bin/bash` 3.2 pulled a newer installer and restarted itself once, the first self-update restart on a real machine. |

The daily job's brief ran once for real on 2026-11-25 against 0.15.48. It opened [pull request #1](https://github.com/thariman/pstack-t3/pull/1), got a Codex Sol review, and sent the Telegram message. Its three wording mistakes are fixed.

Not yet run on a real machine: a held update and a real Claude update failure. Tests cover each. That restart used to switch to the first `bash` on `PATH`, so the rest of the 3.2 run used Homebrew bash 5.2. It now keeps the `bash` that started it, and a full installer run under `/bin/bash` 3.2 passed on the MacBook on 2026-11-25. `check.sh` and `profile.sh` still run under the first `bash` on `PATH`.

## Known limits

- **The check reads names and files, not meaning.** A pstack change in wording that changes behavior passes the check. The `review:` notice and the daily job's pull request are how a person or a review model reads it.
- **The rules run on the honor system.** `t3-mode` is instructions. Nothing checks that an agent restated the goal, listed the playbook steps, or used a second model for review. The planned fix is a transcript grader, then a Claude `Stop` hook for any model that misses often. It is not built.
- **Updates do not happen on launch.** Claude's auto-update for the `cursor-plugins` marketplace is off by default. Turn it on in `/plugin`, on the Marketplaces tab. Grok then follows Claude. Codex never updates on launch. Only `install.sh` updates it. The daily job checks upstream, but it changes `t3-mode`, not your installed pstack.
- **Claude installs pstack over SSH on some machines.** On the MacBook, `claude plugin marketplace add` cloned `git@github.com:cursor/plugins.git`. A machine without a GitHub SSH key can fail at that step.
- **`check.sh` runs under the first `bash` on `PATH`**, not under the `bash` that runs `install.sh`.
- **The daily job runs on one machine.** It needs T3 open there, `gh` signed in, and `~/research/stacks/cursor-plugins`. The other machines only take its merged fixes.
- **A held update stays held until you merge.** Each machine keeps its old pstack, and installs the new one on its first install after the fix lands.

## Sources

- **pstack** by Lauren Tan (poteto), MIT license, from [cursor/plugins](https://github.com/cursor/plugins/tree/main/pstack). Built against version 0.15.36, commit `3dbd22f`, and checked against 0.15.48, commit `9e278fe`. `harness-t3.md` follows the structure of pstack's `docs/harness/claude-code.md`.
- **tstack** by Theo Browne, MIT license, from [t3dotgg/tstack](https://github.com/t3dotgg/tstack). No tstack skill is installed or called. These rules in `harness-t3.md` come from its skills.

| Rule | tstack skill |
| --- | --- |
| Call `orchestrator_capabilities` once and resolve the latest Sol instead of a fixed model id | `sol-loop` |
| If a model is unavailable, drop the seat and say so. Never substitute | `council`, `sol-loop` |
| Each review round is a fresh `delegate_task` with a new `clientRequestId` | `sol-loop` |
| Wait with `watch_pull_request`, unwatch before handoff, children never watch | `babysit-pr`, `full-send` |

Two tstack skills cover jobs pstack has no playbook for. `modernize` decides whether an old PR should be rebased, reworked, or closed. `leaving-pr-comments` labels agent-written PR comments. They are candidates to add.

`github.com/tstack` is Tim Stack's account, the author of lnav. It is unrelated to agent skills.

## Credits

`t3-mode` runs [pstack](https://github.com/cursor/plugins/tree/main/pstack) by Lauren Tan ([@poteto](https://github.com/poteto)), and borrows rules from [tstack](https://github.com/t3dotgg/tstack) by Theo Browne. See [`CREDITS.md`](CREDITS.md).

## License

MIT. See `LICENSE`.

## Develop

Run the checks before you push.

```bash
./check.sh
./profile.sh check
./test-install.sh
```

Update this README in the same commit as any change it describes. `test-install.sh` fails when the example version lines differ from `pstack-verified.txt`, or when a tracked file is missing from the Files table.

`check.sh` with no argument checks the newest installed pstack. Pass a path to check another copy, such as `./check.sh ~/.codex/skills/pstack`.

After you read a new pstack's changes and update `t3-mode` to match, run `./check.sh --record <pstack path>` and commit `pstack-verified.txt`.

## Daily upstream job

A T3 scheduled task, "pstack-t3 daily upstream check", runs [`upstream-job.md`](upstream-job.md) at 08:00 on the Desktop. All runs share one thread, each in a fresh session. On a day when nothing needs a change, it replies with one line and sends nothing. When upstream pstack fails the check or changes a file `t3-mode` follows closely, it starts a `t3-mode` agent that:

1. updates `t3-mode` on a branch in a separate worktree, so the live skill on that machine never changes mid-run
2. updates this README for every change, runs the checks, records the new pstack, and opens a pull request
3. asks a Codex Sol reviewer for a second opinion and fixes what it finds
4. sends the pull request link to Telegram

It never merges. Every machine keeps its current pstack until you merge and rerun the installer.
