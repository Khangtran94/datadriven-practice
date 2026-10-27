# Analysing a SQL week (dag.sql vs gold_submit.sql)

The README gives per-column counts (correct / wrong / missed) and rows built. Use them first:
`visit key missed` = visits never built (every column loses those rows); a column's missed minus that number = NULLs in built rows.

1. Qualify (README + dag.sql + gold_submit.sql), use the finder script.
2. Build synthetic raw tables from the README conditions (references/examples/week6-sql-analysis/gen.py). Do not invent value shapes the README
   does not mention; if you must, say so, and keep them out of the comparison with the user's code.
3. Run gold and dag.sql night by night with the landing windows and incremental merge.
4. **Ablate**: patch one thing at a time in dag.sql, count matches vs gold per column, then all together. A fix with no visible effect
   on synthetic data is `[inferred]`, not `[estimate]`. If the remaining gap is far smaller than the measured loss, say the cause is not fully explained and name the suspects.
5. Trace one mismatching key through the CTEs (render the task, cut before the final SELECT, query a CTE) to find root causes such as an unhandled null marker.
6. Write the analysis: one section per root cause, Before = verbatim lines, After = tested patch, Proof = the ablation numbers.

Typical SQL-week root causes seen so far: strict key shape check, only some timestamp offset forms, newest row taken even when NULL,
state vocabulary gaps, integer-only numbers, null markers handled in some columns only, join day with no fallback, camelCase JSON keys.
