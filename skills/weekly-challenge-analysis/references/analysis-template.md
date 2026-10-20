# Claude_Analysis.md structure

Title: `# Week N: <Name>: handler.py vs gold_submit.py`

Header lines: score, rank, points, records recovered, work per record, statements (from the README),
plus one line of context. Add the evidence-tag legend (`[measured]`, `[inferred]`, `[estimate]`,
`[not available]`, `[untested]`).

If the score is 0 or the run failed, add **Why your score was 0** directly under the header
(cause, what the handler kept, what the platform measured, why the sample hid it).
See run-failures.md.

## Impact ranking
Table: # | Area | Penalty (measured or inferred) | Gap vs gold. Biggest gap first.

## Sections (one per row of the table, in the same order)
Each section has exactly these fields:
- **Your code** (short snippet + line range)
- **Gold code** (short snippet + line range, or `[not available]`)
- **Example input** (a concrete line or pattern from the feed)
- **Your behavior** / **Gold behavior** (what each does on that input)
- **Why it matters** (README share of stream, wrong/missed counts)
- **Before** (the user's current code, verbatim, with line range)
- **After** (the proposed code)
- **How it works** (plain language: what changed, why it fixes the problem, what stays the same)
- **Proof** (what you ran: stream size, old vs new output, memory/time figures; or `[untested]`)

For small fixes, Before/After can be a few lines. For a run-level failure, After is the complete
replacement class, runnable.

## Not compared
List anything that could not be compared because the gold file was incomplete.

## Recommended pattern
A code skeleton. `process()` returns `[]` and `finalize()` emits reconciled rows when revisions or
merges can arrive late. If the task needs per-line emission, say so and keep the rule: never emit the
same key from both `process` and `finalize` (Week 1 lost 1,709,876 points that way).

## Checklist (run-level failures only)
A short list the user can reuse next week.
