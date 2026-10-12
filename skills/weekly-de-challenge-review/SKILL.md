---
name: weekly-de-challenge-review
description: Analyze weekly DataDriven data-engineering challenge submissions by comparing the user's handler with the gold solution, explaining score impact, correctness, and memory/performance improvements.
---

# Weekly DE Challenge Review Skill

## Purpose

Help Khang learn from each weekly DataDriven challenge by comparing the submitted implementation with the gold solution, identifying the highest-impact gaps, and drafting a clear, evidence-based analysis document. Prioritize understanding and reusable engineering techniques over merely proposing a replacement.

## Repository and folder eligibility

Repository: `Khangtran94/datadriven-practice`

For every folder under `weekly/`, apply case-sensitive filename checks in this order:

1. If the exact path `weekly/<week-folder>/GPT_Analysis.md` exists, skip that folder completely. Never rewrite or overwrite it.
2. If the uppercase file is absent but `GPT_analysis.md` exists, do not overwrite either file or create a competing case-only duplicate. Report the naming mismatch and propose a migration/merge for approval.
3. If neither analysis file exists, proceed only if all three files exist: `README.md`, `handler.py`, and `gold_submit.py`.
4. If any required file is missing, skip the folder for this run and check it again on a later run.
5. Read the three required files and relevant starter/context files before drawing conclusions.

## Evidence and score interpretation

- Extract the score and rank from that week's README when present; state when either is absent.
- Separate measured facts (score, rank, explicit evaluator feedback, tests, or observed errors) from hypotheses about causes.
- Never claim a specific penalty or runtime behavior unless the available evidence supports it.
- Explain score 0 explicitly when evidence says the run ran out of memory: trace the relevant data structures and their lifetime, explain why retaining candidates for every key can grow without bound, and distinguish this confirmed cause from any secondary hypotheses.
- Prioritize findings by likely score impact, then correctness, memory, runtime, and maintainability. Explain uncertainty.

## Required analysis document structure

Write a proposed `weekly/<week-folder>/GPT_Analysis.md` with:

1. Week title and a concise comparison of `handler.py` versus `gold_submit.py`.
2. Score and rank from README.
3. An impact-ranking table near the top, including issue, evidence/location, likely impact, and recommended change.
4. Impact-ordered sections. For each important difference include:
   - exact function and line/code anchor when available;
   - a minimal concrete example input or stream sequence;
   - what the user's handler does;
   - what the gold solution does;
   - why the difference matters to correctness, score, memory, or runtime;
   - a specific recommended change.
5. Code before: the relevant pattern from the current handler.
6. Proposed code after: the minimal corrected/improved pattern, respecting the challenge's allowed libraries and interface.
7. Explain the change in plain language, including trade-offs and what to learn for future challenges.
8. End with a recommended pattern skeleton. Emphasize that `process()` should return `[]` and `finalize()` should emit reconciled rows when appropriate to the task; do not apply this pattern blindly if the task contract requires immediate output.

## Engineering review checklist

Inspect, as relevant to the actual task:

- Streaming and state growth: whether data is retained per key, whether aggregation can replace full candidate history, whether state can be bounded, and whether final reconciliation is possible.
- Correctness: schema and types, key normalization, duplicate handling, ordering, null/malformed input, timestamp parsing, tie-breaking, and exact output contract.
- Lifecycle: what `process()` emits, what state it retains, and what `finalize()` emits.
- Complexity: time and space costs, especially state proportional to all rows versus distinct keys or compact aggregates.
- Constraint compliance: allowed imports, required class/method signatures, and output schema.
- Do not recommend deduplication or any other transformation unless the specific task semantics support it.

## Code quality and teaching style

- Keep the user's existing `Handler.process()` and `Handler.finalize()` interface.
- Prefer small helper functions where they clarify distinct transformations, without overengineering.
- Show focused before/after snippets, not only a complete rewrite.
- Explain the reasoning step by step and include examples that demonstrate the behavior.
- Treat `gold_submit.py` as evidence of a reference implementation, not proof that every implementation detail is mandatory.
- Do not invent line numbers, tests, input data, benchmark results, or evaluator feedback. If line numbers are unavailable, use function names and short code anchors.
- Make recommendations specific enough that the user can apply them and understand why they work.

## Approval and repository safety

- Draft the complete analysis and present it to Khang for discussion, including the exact target path.
- Do not create or edit `GPT_Analysis.md`, and do not commit or push analysis changes, until Khang explicitly approves the draft.
- Creating or updating this reusable skill file does not authorize edits to weekly analysis files.
- Never overwrite an existing analysis file, and never automatically resolve a case-only filename conflict.
