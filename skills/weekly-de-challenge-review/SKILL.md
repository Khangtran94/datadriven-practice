---
name: weekly-de-challenge-review
description: Analyze weekly DataDriven data-engineering challenge submissions by comparing the user's handler with the gold solution, explaining score impact, and teaching concrete before/after fixes, especially for score-zero memory failures.
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
- For a memory failure, describe the state growth in plain language and, where the code supports it, give complexity in terms of total input rows (N), distinct keys (K), and retained candidates. Explain why a compact per-key aggregate or bounded state can be safer, but only propose it if it preserves the task semantics.
- Prioritize findings by likely score impact, then correctness, memory, runtime, and maintainability. Explain uncertainty.

## Required analysis document structure

Write a proposed `weekly/<week-folder>/GPT_Analysis.md` with:

1. Week title and a concise comparison of `handler.py` versus `gold_submit.py`.
2. Score and rank from README, including explicit explanation of score 0 and the evidenced failure cause when applicable.
3. An impact-ranking table near the top, including issue, evidence/location, likely impact, and recommended change.
4. Impact-ordered sections. For each important difference include:
   - exact function and line/code anchor when available;
   - a minimal concrete example input or stream sequence;
   - what the user's handler does;
   - what the gold solution does;
   - why the difference matters to correctness, score, memory, or runtime;
   - a specific recommended change.
5. **Code before — my current code:** include the actual relevant code from the user's current `handler.py`, not a generic illustrative substitute. Include the full affected method/function and any helper/state definitions needed to understand its behavior. Preserve the code exactly in the before snippet, apart from optional comments that are clearly marked as explanatory. If the problem depends on the interaction among methods or state, include the complete current `Handler` class when practical. Do not use `gold_submit.py` as the "before" code.
6. **Code after — proposed change:** provide the concrete replacement code that implements the recommendation. Include the complete modified method(s) and all changed/new helper functions and state definitions. If a full class replacement is practical, show the complete proposed `Handler` class. If unchanged sections are omitted for brevity, identify them explicitly and make the snippet's replacement boundaries unambiguous. The proposal must preserve the required interface and allowed libraries.
7. **Explanation document, not just code:** explain the original bug, the root cause, the proposed fix step by step, a small worked example, why the new state/output behavior is safer, time and space trade-offs, edge cases, and a reusable lesson for future challenges. Explain any behavior that must remain unchanged. State which claims are proven by the provided evidence and which are hypotheses.
8. A short validation checklist with tests derived from the task contract, including empty input, multiple keys, repeated keys, ordering/tie cases, malformed/null values when relevant, and a large-stream/memory-oriented scenario when relevant. Do not claim tests were run unless they actually were.
9. End with a recommended pattern skeleton. Emphasize that `process()` should return `[]` and `finalize()` should emit reconciled rows when appropriate to the task; do not apply this pattern blindly if the task contract requires immediate output.

## Special score-zero / out-of-memory teaching section

When the score is 0 and evaluator evidence identifies out-of-memory (OOM), add a prominent section titled **Why the score was 0: memory exhaustion**. It must:

1. Quote or accurately paraphrase the available evaluator feedback and point to its source; do not invent evidence.
2. Trace exactly which dictionary/list/set or other object accumulates data, what each entry represents, and why its lifetime spans the stream.
3. Show the relevant current code under **Before: current implementation** and the specific proposed replacement under **After: memory-safe approach**.
4. Walk through a small example with multiple keys and candidates, showing what is retained before versus after.
5. Explain why keeping every candidate per key can make memory scale with all rows/candidates, while storing only sufficient per-key state may scale with distinct keys—only if the task's rules allow that reduction.
6. Discuss finalization and correctness risks: ties, duplicates, ordering, late-arriving records, and whether discarded candidates could later be needed. Never drop history unless the semantics prove it safe.
7. Include a concise prevention checklist for future streaming challenges: identify retained state, estimate its growth, ask what information is truly necessary, and test large input behavior.
8. Do not promise that a proposed fix guarantees a nonzero score. Explain that correctness and evaluator behavior still need validation.

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
- The report must be useful as a learning document even when no score-zero/OOM issue exists: explicitly teach the main bug and prevention principle, not just present code.

## Approval and repository safety

- Draft the complete analysis and present it to Khang for discussion, including the exact target path.
- Do not create or edit `GPT_Analysis.md`, and do not commit or push analysis changes, until Khang explicitly approves the draft.
- Creating or updating this reusable skill file does not authorize edits to weekly analysis files.
- Never overwrite an existing analysis file, and never automatically resolve a case-only filename conflict.
