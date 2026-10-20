---
name: weekly-de-challenge-review
description: Analyze weekly DataDriven data-engineering challenges across Python streaming and SQL/DAG submissions by comparing user code with reference solutions, explaining score impact, and teaching concrete before/after fixes.
---

# Weekly DE Challenge Review Skill

## Purpose

Help the user learn from each weekly DataDriven challenge by comparing the submitted implementation with the reference solution, identifying the highest-impact gaps, and drafting a clear, evidence-based analysis document. Prioritize understanding and reusable engineering techniques over merely proposing a replacement.

## Repository and folder eligibility

Repository: `Khangtran94/datadriven-practice`

For every folder under `weekly/`, apply case-sensitive filename checks in this order:

1. If the exact path `weekly/<week-folder>/GPT_Analysis.md` exists, skip that folder completely. Never rewrite or overwrite it.
2. If the uppercase file is absent but `GPT_analysis.md` exists, do not overwrite either file or create a competing case-only duplicate. Report the naming mismatch and propose a migration/merge for approval.
3. If neither analysis file exists, inspect the challenge files and determine the type from the actual repository structure and README instructions:
   - **Python challenge:** require `README.md`, `handler.py`, and `gold_submit.py`.
   - **SQL/DAG challenge:** require `README.md`, `dag.sql`, and `gold_submit.sql`.
4. If both sets of files exist, follow the README and actual execution contract to determine the authoritative submission type. If unclear, flag the ambiguity instead of guessing.
5. If required files for the identified type are missing, skip that folder for this run and check it again later.
6. Read the required files and relevant starter, configuration, schema, and context files before drawing conclusions.

Never classify a challenge from its week number alone.

## Evidence and score interpretation

- Extract score and rank from that week's README when present; state when either is absent.
- Separate measured facts (score, rank, explicit evaluator feedback, tests, or observed errors) from hypotheses about causes.
- Never claim a specific penalty or runtime behavior unless available evidence supports it.
- For a confirmed Python out-of-memory (OOM) failure, trace the relevant data structures and their lifetime. Explain why retaining candidates for every key can grow with the stream, distinguishing the confirmed cause from secondary hypotheses.
- For memory failures, explain state growth in plain language and, where code supports it, give complexity in terms of total input rows (N), distinct keys (K), and retained candidates. Suggest compact per-key aggregates or bounded state only when this preserves task semantics.
- For SQL/DAG failures, identify the failing task and root cause only when supported by evaluator feedback, logs, or other concrete evidence. Distinguish SQL logic defects, dependency/configuration problems, and runtime/environment failures.
- Prioritize findings by likely score impact, then correctness, memory/runtime or query cost, and maintainability. Explain uncertainty.

## Required analysis document structure

Write a proposed `weekly/<week-folder>/GPT_Analysis.md` with:

1. Week title, detected challenge type, and concise comparison of the user's submission with the reference solution.
2. Score and rank from README, plus relevant explicit evaluator feedback and the evidenced cause of score 0 when available.
3. An impact-ranking table near the top, including issue, evidence/location, likely impact, and recommended change.
4. Impact-ordered findings. For each important difference include:
   - exact function, SQL section, task/configuration, and line/code anchor when available;
   - a minimal concrete input, data example, or execution scenario;
   - what the user's implementation does;
   - what the reference solution does;
   - why the difference matters to correctness, score, memory, runtime, or query cost;
   - a specific recommended change;
   - a clear distinction between proven facts and hypotheses.
5. **Code before — my current implementation:** include the actual relevant code from the user's submission, not a generic substitute. For Python, include the complete affected method and relevant helper/state definitions; include the complete Handler class when practical. For SQL, quote the actual relevant query/CTE/task SQL and relevant DAG configuration.
6. **Code after — proposed change:** provide concrete replacement code or SQL implementing the recommendation. Include all changed/new helper functions, state definitions, CTEs, task configuration, and dependencies needed to make the change understandable. Make replacement boundaries unambiguous. Preserve the task's interface, dialect, schema, and execution contract.
7. **Explanation, not just code:** explain the original issue/root cause, proposed fix step by step, a worked example, expected state/output behavior, relevant time/space or query-performance trade-offs, edge cases, and a reusable lesson. Explain behavior that must remain unchanged.
8. A short validation checklist with tests or queries derived from the task contract. Do not claim tests were run unless they actually were.
9. End with reusable patterns and lessons relevant to the detected challenge type.

## Python challenge review

Inspect the actual task contract and compare `handler.py` with `gold_submit.py`.

- Preserve the required `Handler.process()` and `Handler.finalize()` interface and allowed libraries.
- Inspect streaming state growth, per-key retention, aggregation, final reconciliation, output timing, and whether state can safely be bounded.
- Check schema/types, key normalization, duplicates, ordering, NULL/malformed input, timestamp parsing, tie-breaking, and exact output contract as relevant.
- Explain lifecycle: what `process()` emits, what state it retains, and what `finalize()` emits.
- Discuss time/space complexity, especially state proportional to all rows versus distinct keys or compact aggregates.
- Do not recommend deduplication or any other transformation unless task semantics support it.
- A `process()` that returns `[]` and a `finalize()` that emits reconciled rows is appropriate only when the task contract supports deferred output; do not apply it blindly.

## SQL and DAG review

Inspect the actual challenge contract, SQL files, DAG definitions, schemas, and available execution evidence.

### SQL correctness

- Identify the intended output grain: what one row represents.
- Check primary/business keys, join cardinality, duplicate creation, missing records, and source-to-output reconciliation.
- Review filters, aggregations, CTEs, window functions, ranking, and deduplication.
- Check NULL handling, data types, casts, timestamps, time zones, and boundary conditions when relevant.
- Validate counts, totals, and reconciliation when required by the task.
- Check incremental-load behavior, idempotency, late-arriving data, and reruns when relevant.
- Respect the SQL dialect and engine shown by the repository; do not assume unsupported syntax.

### DAG and execution behavior

- Identify tasks, dependencies, and intended execution order from the actual DAG.
- Inspect materialization, task configuration, inputs, outputs, and referenced tables.
- Use explicit evaluator feedback or execution logs to identify a failing task.
- Explain the difference between a SQL logic defect, a dependency/configuration issue, and a runtime/environment failure.
- Do not claim a task failed for a particular reason unless available evidence supports it.

### Performance and validation

- Discuss scans, joins, aggregations, partitioning, and query cost only when relevant to the known engine and available evidence.
- Propose validation queries or test cases for correctness, duplicates, NULLs, boundary dates, and reconciliation.
- Clearly distinguish tests that were actually executed from tests merely recommended.
- Do not invent schemas, query plans, runtime metrics, database-engine behavior, or evaluator results.
- Treat `gold_submit.sql` as a reference implementation, not proof that every implementation detail is mandatory.


### PostgreSQL companion SQL for non-PostgreSQL challenges

For every eligible **SQL/DAG challenge** that has `README.md`, `dag.sql`, and `gold_submit.sql`, identify the SQL dialect/engine actually used by `gold_submit.sql` from its syntax, functions, configuration, and README—not from the filename or week number alone.

- If the reference SQL is already PostgreSQL-compatible, do not create a duplicate PostgreSQL file.
- If the reference SQL uses a different dialect (for example SQLite, BigQuery, Snowflake, or MySQL), create a companion file at `weekly/<week-folder>/GPT_gold_submit_Postgres.sql`.
- Preserve `gold_submit.sql` unchanged. Never rename, replace, or overwrite the original reference or an existing `GPT_gold_submit_Postgres.sql`. If the companion already exists, inspect it if useful, but do not overwrite it automatically; report whether it appears to need review.
- Translate all task queries and relevant SQL logic to PostgreSQL, including JSON operations, date/time parsing, string/pattern matching, numeric casts/rounding, and NULL behavior as applicable. Preserve the intended output columns, grain, keys, filters, joins, and business semantics. Adapt engine-specific syntax deliberately rather than performing blind text substitutions.
- Keep DAG orchestration/materialization configuration separate from SQL execution semantics. Explain in comments when the companion contains query SQL only and scheduling/materialization must be handled by the existing runner.
- Prefer broadly compatible PostgreSQL syntax. If the translation requires a particular PostgreSQL version or extension, state that requirement at the top of the file.
- Validate the result as far as the available environment permits. Check for remaining source-dialect-only functions and syntax, review each task/query, and compare against sample expectations when sample data and a PostgreSQL runtime are available. Never claim the SQL was executed or sample-validated unless it actually was.
- If no PostgreSQL runtime is available, perform a careful static review and add a brief header comment saying execution/sample validation remains outstanding. Do not present an unexecuted translation as production-validated.
- Commit the new companion SQL file to the repository when the user has authorized this workflow, using a descriptive commit message. This SQL-file commit is independent of the approval gate for `GPT_Analysis.md`: never create/commit an analysis report until the user approves its draft.
- In the review response, state the source dialect, link the new file and commit when created, note PostgreSQL version requirements, and clearly distinguish static review from actual execution.

## Special score-zero / out-of-memory teaching section

When score is 0 and evaluator evidence identifies OOM in a Python challenge, add a prominent section titled **Why the score was 0: memory exhaustion**. It must:

1. Quote or accurately paraphrase the available evaluator feedback and identify its source.
2. Trace exactly which dictionary/list/set or other object accumulates data, what each entry represents, and why its lifetime spans the stream.
3. Show the relevant current code under **Before: current implementation** and the specific proposed replacement under **After: memory-safe approach**.
4. Walk through a small example with multiple keys and candidates, showing what is retained before versus after.
5. Explain why keeping every candidate per key can make memory scale with all rows/candidates, while storing only sufficient per-key state may scale with distinct keys—only if the task rules allow that reduction.
6. Discuss finalization and correctness risks: ties, duplicates, ordering, late-arriving records, and whether discarded candidates could later be needed. Never drop history unless semantics prove it safe.
7. Include a concise prevention checklist: identify retained state, estimate its growth, ask what information is necessary, and test large-input behavior.
8. Do not promise that a proposed fix guarantees a nonzero score; correctness and evaluator behavior still need validation.

For SQL/DAG score-zero failures, use a similarly prominent explanation of the confirmed failing task and cause when evidence is available. Do not label a SQL failure as OOM or invent a root cause without evidence.

## Code quality and teaching style

- Keep the user's required interfaces, schema, and execution contract intact.
- Prefer small helper functions or clearly separated SQL CTEs when they clarify transformations, without overengineering.
- Show focused before/after snippets and provide complete replacement boundaries.
- Explain reasoning step by step and include examples that demonstrate behavior.
- Treat the reference implementation as evidence, not proof that every implementation detail is mandatory.
- Do not invent line numbers, tests, input data, benchmark results, query plans, or evaluator feedback. If line numbers are unavailable, use function names and short code anchors.
- Make recommendations specific enough that the user can apply them and understand why they work.
- The report must remain a learning document even when no score-zero issue exists: teach the main bug and prevention principle, not just present code.

## Approval and repository safety

- Draft the complete analysis and present it to the user for discussion, including the exact target path.
- Do not create or edit any weekly `GPT_Analysis.md`, and do not commit or push analysis changes, until the user explicitly approves that analysis draft.
- Creating or updating this reusable skill file does not authorize edits to weekly analysis files.
- Never overwrite an existing analysis file, and never automatically resolve a case-only filename conflict.
