# Daily upstream job

Goal: keep `t3-mode` matched to the newest pstack, so every machine can take pstack updates without the installer holding them. You change `t3-mode` only. You never merge, and you never touch an installed pstack.

`<repo>` is `~/projects/pstack-t3`. `<upstream>` is `~/research/stacks/cursor-plugins`, a clone of `github.com/cursor/plugins`.

1. Get the newest pstack.

   ```bash
   git -C <repo> fetch -q origin
   git -C <upstream> fetch -q origin
   new=$(mktemp -d); git -C <upstream> archive origin/main pstack | tar -x -C "$new"
   <repo>/check.sh "$new/pstack"
   ```

2. If the check passes and prints no `review:` line, reply `pstack <version>: t3-mode already matches.` and stop. Open no branch and send no message.

3. Otherwise make a worktree, so the live skill in `<repo>` never changes during the run. Use the version from `$new/pstack/plugin.json`.

   ```bash
   git -C <repo> worktree add -q ~/.local/share/pstack-t3-work/pstack-<version> -b pstack-<version> origin/main
   ```

   If the branch exists, an earlier run started this version. Run `gh pr list --repo thariman/pstack-t3 --head pstack-<version> --state all --json url,state`.
   - An open or merged pull request: reply with its URL and stop.
   - A closed one: the user turned it down. Reply with its URL and stop.
   - None: the earlier run stopped part way. Find its worktree with `git -C <repo> worktree list`, or add one for the existing branch with `git -C <repo> worktree add -q <path> pstack-<version>`, and continue from step 4 there.

4. Find what changed. The first line of `<repo>/pstack-verified.txt` names the version last read by hand. Find that version's commit with `git -C <upstream> log origin/main --format=%h -S'"version": "<old>"' -- pstack/plugin.json | tail -1`. Read `git -C <upstream> diff <old commit> origin/main -- pstack` for every file the check or the `review:` line names, and read the rest of the diff's stat.

5. In the worktree, update `t3-mode` only where pstack changed something it maps.
   - `skills/t3-mode/harness-t3.md` for Cursor names, files, and rules about briefs, subagents, or models.
   - `skills/t3-mode/profiles/*.md` for added, removed, or renamed roles. Keep the user's choices: code on Codex latest Sol with `ultrafast`, Sol as a panel seat, Grok as the one-way door seat. When pstack changes a default model, apply it only to the seats that already follow pstack's default for that role.
   - `README.md` where it describes what you changed.
   - Write prose per pstack's `unslop` skill. Make no change pstack did not cause.

6. Check, record, and test in the worktree.

   ```bash
   ./check.sh "$new/pstack" && ./check.sh --record "$new/pstack" && ./profile.sh check && ./test-install.sh
   ```

   Commit with a message that names the pstack version, push with `git push -u origin pstack-<version>`, and open a pull request with `gh pr create`. Its body opens with `## Why`, then lists each pstack change and the `t3-mode` change it caused, and each pstack change you judged needs nothing, with the reason.

7. Get a second opinion. Start one `delegate_task` with `role: "review"`, Codex latest Sol, `reasoningEffort: high`, `serviceTier: "ultrafast"`. Its brief opens `Review only. Do not edit, commit, push, comment on PRs, or start subagents.` and gives the pull request URL, the worktree path, the upstream diff range, and this goal. Fix each finding you agree with, rerun step 6's checks, and push. Add a `## Review` section to the pull request body that lists each finding with what you fixed, and each one you reject with the reason. Edit the body with `gh api -X PATCH repos/thariman/pstack-t3/pulls/<number> -F body=@<file>`, because `gh pr edit` fails on the Projects (classic) deprecation.

8. Send the result to Telegram. Feed it on stdin, never as an argument.

   ```bash
   hermes-tg <<'EOF'
   pstack-t3: pstack <version> needs a t3-mode update. Review and merge: <PR URL>
   <two or three sentences on what changed>
   EOF
   ```

9. Reply with the pull request URL, the head commit, and the review's state. Leave the worktree in place until the pull request merges.
