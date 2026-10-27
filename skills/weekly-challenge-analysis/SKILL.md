---
name: weekly-challenge-analysis
description: Compare Khang's handler.py with the top-1 gold_submit.py for each weekly DataDriven "Gauntlet" challenge in the GitHub repo Khangtran94/datadriven-practice, and write a Claude_Analysis.md in the matching week folder, with before/after code and plain-language explanations. Also writes a Claude_gold_submit_Postgres.sql for any SQL week whose gold_submit.sql is not PostgreSQL (e.g. SQLite). Use whenever the user asks to check the repo for new weeks, analyze a week's handler vs gold, explain why a week scored low or scored 0, write or update a Claude_Analysis.md, port a gold_submit.sql to Postgres, or mentions the Gauntlet, datadriven-practice, gold_submit.py, gold_submit.sql, dag.sql, or a week-NN folder, even if they don't name this skill.
---

# Weekly challenge analysis

Each week folder under `weekly/` holds the challenge README (with the graded result),
`handler.py` (the user's submission) and `gold_submit.py` (the top-1 submission). The goal is a
`Claude_Analysis.md` that shows the user, with evidence, where their code lost points against the
winner, what to change, and how the fix works, so they can avoid the same problem next week.

## Rules that always apply

- **Never overwrite `Claude_Analysis.md`.** If it exists, skip that folder entirely and say so. It may contain the user's edits.
- **Draft in the chat first.** Do not create files in the repo, commit or push until the user explicitly approves the draft. They review content before it lands, and a commit is hard to take back.
- **Reading needs no token.** The repo is public, so use `git clone`. A token is only needed to push after approval.
- **Handle the token carefully.** Pass it as a one-off request header (`git -c http.extraheader=...`). Never put it in a remote URL, git config, a file, or memory. After pushing, remind the user to revoke it. A fine-grained token limited to this repo with Contents read/write is enough.
- **Qualify before working.** A Python week needs `README.md`, `handler.py` and `gold_submit.py`. A SQL week needs `README.md`, `dag.sql` and `gold_submit.sql`. If a file is missing, skip the folder, say which file is missing, and leave it for a later run. Decide the type from the files and the README, never from the week number.
- **Postgres companion for non-Postgres SQL weeks.** The user knows Postgres best, so a SQL week whose `gold_submit.sql` is not Postgres gets a new `Claude_gold_submit_Postgres.sql` next to it. The user asked for these to be committed directly, so the draft-approval gate above does not apply to this file (it still applies to `Claude_Analysis.md`). Follow the section "SQL weeks: PostgreSQL companion file" below.
- **Stay independent.** Other models' analyses (`Grok_Analysis.md`, `GPT_Analysis.md`) may exist. Don't copy them; build the analysis from the README, handler and gold files.

## Workflow

1. **Find the weeks.** Run `scripts/find_ready_weeks.py`. Report one line per folder: ready (Python or SQL), skipped (analysis exists) or waiting (missing file). For SQL weeks it also prints the guessed dialect and whether the Postgres companion exists. Continue only with ready folders.
2. **Read the three files with line numbers** (`cat -n`) so every claim can cite lines. Read any starter files if the README mentions them.
3. **Check the gold file is complete.** Look for a `Handler` class with `process` and `finalize`. If it ends early, compare only the helpers that exist and mark everything else `[not available]`. Never guess what missing code does.
4. **Read the README result table before comparing code.** If the score is 0, records recovered is 0, or the run crashed or timed out, the per-condition table (all 0%) says nothing about individual conditions. Find the run-level cause first and follow `references/run-failures.md`.
5. **Compare in impact order.** Rank by what the README measured (wrong and missed counts, points lost). When nothing was measured, rank by each condition's share of the stream and say that it is inferred.
6. **SQL weeks: follow `references/sql-week-analysis.md`** (synthetic data, night-by-night run, one-fix-at-a-time ablation). Worked example: `references/examples/week6-sql-analysis/`.
6b. **Draft using `references/analysis-template.md`.** Every section where you recommend a change must show **Before** (the user's actual code), **After** (the proposed code), **How it works** (plain language) and **Proof**. See "Before, after and explanation" below.
7. **Present the complete draft and the target path** (`weekly/WEEK-FOLDER/Claude_Analysis.md`), end with 2–3 questions, then stop and wait for approval.
8. **After explicit approval:** clone with the token header, add only the new file(s), and commit to `main` (the user's standing choice). If the push is rejected, `git fetch`, `git rebase origin/main` and push again. Never force-push. Verify the remote head matches the local commit, then remind the user to revoke the token.

## Before, after and explanation

The user wants to understand the fix well enough to avoid the problem next time, not just receive a patch.

- **Before:** copy the user's code exactly as it is in the file, with line numbers. Never paraphrase it. Extract it with `sed -n` so it is verbatim.
- **After:** the proposed code. For a small fix, show the changed function or lines. For a run-level failure (score 0, crash, timeout, out of memory), show the complete replacement class or function, runnable, and say which parts of the file stay unchanged.
- **How it works:** explain in plain language what each changed part does, why it fixes the problem, and what stays the same. Use one concrete analogy or number if it helps.
- **Checklist:** for run-level failures, end with a short checklist the user can reuse on the next week.
- **Test the After code before presenting it.** Build a synthetic stream from the README's conditions, run old and new code on it, and compare outputs and (for memory or time) peak usage. Report the stream size and exact figures. If you could not test something, label it `[untested]`. Never present untested code as a fix. `references/examples/week4-memory-fix.md` is a worked example.

## Evidence tags

Mark every claim, so the reader can tell what was proven from what was guessed.

- `[measured]` comes from the README or platform feedback.
- `[inferred]` comes from reading the code.
- `[estimate]` comes from a local test you ran. Say it was synthetic data.
- `[not available]` marks code that isn't in the repo.
- `[untested]` marks proposed code you could not run.

## Style

Write for a data engineer who wants to learn from the comparison. Explain why a difference matters, not only what differs. Keep snippets short and cite line ranges. Every section needs example input, both behaviors, why it matters, and the before/after/how-it-works trio. Do not pad.

## SQL weeks: PostgreSQL companion file

Applies to a folder that has `README.md`, `dag.sql` and `gold_submit.sql`. Details, gotchas and a worked example are in `references/postgres-port.md` and `references/examples/week5-postgres-port/`.

1. **Identify the dialect from the syntax**, not the filename. SQLite signs: `GLOB`, `quote(`, `instr(`, `datetime(..., 'unixepoch')`, `json_extract(`, `char(9,10,13)`. If the gold is already Postgres, create nothing and say so.
2. **Never touch existing files.** Do not edit `gold_submit.sql` or `dag.sql`. If `Claude_gold_submit_Postgres.sql` already exists, do not overwrite it; report that it exists. Other models' files (`GPT_gold_submit_Postgres.sql`, `Grok_gold_submit_Postgres.sql`) are not inputs; port from the gold file.
3. **Port faithfully.** Same DAG header, same task order, same output columns and logic. Do not fix or improve the gold. If something looks off (for example hard-coded dates that differ from the README window), keep it, put one comment in the file header and tell the user in chat.
4. **Plain SQL only.** The user is not familiar with Postgres functions. No `CREATE FUNCTION`, `DO` blocks, extensions or procedural code. Build each task as one `WITH ... SELECT` in clear steps (`b` trim, `c` null markers, `n` prepare text, `p` cast, final `SELECT`), with a short comment per step.
5. **Header comment** states: PostgreSQL version needed (`pg_input_is_valid()` needs 16+), assumptions (for example all raw columns are TEXT), what was copied from gold on purpose, and a short SQLite to Postgres cheat sheet.
6. **Test before committing.** Install Postgres (`apt-get install postgresql`, start the cluster), generate synthetic raw tables from the README's conditions, run the gold in SQLite (python `sqlite3`) and the port in Postgres on identical data, then compare every task table and the final table row by row. Use several seeds. Report stream sizes and the result. Explain any difference that comes from an engine quirk. If a runtime is not available, say the port is `[untested]` and put that in the file header.
7. **Commit only that file**, with a descriptive message, to `main`. Push with the token header; if rejected, `git fetch`, `git rebase origin/main` and push again. Never force-push. Remind the user to revoke the token. Do not store the token anywhere.
8. **Report** the source dialect, the version requirement, what was tested and the commit hash.
