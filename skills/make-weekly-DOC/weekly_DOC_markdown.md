---
name: "Make Weekly Challenge Markdown"
description: "Create a detailed weekly DataDriven challenge Markdown file with correctly placed sample tables."
argument-hint: "week-8"
agent: "agent"
---

Create a self-contained Markdown file named `$ARGUMENTS.md` for the DataDriven challenge week identified by `$ARGUMENTS` (for example, `week-8`).

## Retrieve the source

1. Use the available DataDriven MCP tools to confirm the requested week and retrieve its complete brief, schemas, rules, schedule, and sample input and expected output rows.
2. Prefer `weekly_challenge_text` for a readable full brief. Use `weekly_challenge` when the structured response is useful to recover details or verify schema and sample data.
3. If the DataDriven MCP server or requested week is unavailable, stop and tell me what is missing. Do not invent, infer, fabricate, or silently omit challenge rules or sample values.
4. Do not assume files or context from another PC, workspace, or previous chat are available. If I provide existing weekly files, use them as style references.

## File organization

Create the file in the current workspace. Use these five sections, adjusting only the Section 1 or 2 title to reflect whether the challenge has raw tables or stream input:

1. `## 1) Raw tables` or `## 1) Raw input`
2. `## 2) Target table` (include the target table name when the brief provides one)
3. `## 3) Notes` (include the relevant source team in the heading if useful)
4. `## 4) Expected sample output`
5. `## 5) The schedule` or `## 5) Execution schedule`

Keep each section exactly once and in that order.

### Section 1: Inputs and sample rows

- Describe every raw table or stream: its purpose, row volume, retention or scope, documented columns and types, and other relevant details from the brief.
- Put each actual input sample table in this section, directly with its corresponding input description.
- For database tables, use the documented column names and column order. Preserve sample row order and values. Display SQL/source nulls as `NULL` and preserve source-specific null markers (such as `\N`) when they are literal sample values.
- For JSON-object stream inputs, make a table using the union of keys present across the sample records. Keep fields in first-seen order. Show `*not present*` when a JSON key is absent and `NULL` when it is present with JSON null. Preserve other field values as represented in the source.
- For HL7 or other multiline records, use a Markdown table with wrapper fields as columns and the message in a cell. Separate message segments with `<br>` and preserve segment contents. Keep optional or extra wrapper fields rather than dropping them.
- Include the input sample counts. Do not add a separate “Landed on” list unless I explicitly ask for it.

### Section 2: Target and expected rows

- Describe the target schema: column names, documented types, keys, nullability, constraints, and scoring/correctness rules.
- Put the expected target rows in a Markdown table under this section, after the schema description.
- Order target columns exactly as in the target schema, not in the order of the JSON properties.
- Preserve every output value. Display null values as `NULL`.
- State the expected output row count.

### Section 3: Notes

Summarize the brief's meaningful business rules and edge cases, including normalization, time zones, deduplication, corrections, ordering, status precedence, and exclusions, as applicable. Preserve important distinctions and do not invent rules.

### Section 4: Expected sample output

Briefly report the sample input row count for each input table or stream and the expected target row count. The detailed expected rows belong only under Section 2; do not duplicate them here.

### Section 5: Schedule

Include the run dates and timing, data window, execution model, language/runtime requirements, memory budget, and runtime cap specified by the brief, as applicable. For streaming challenges, describe the handler model rather than inventing calendar dates.

## Validation before finishing

- Check sample row counts against the brief for every input and the target.
- Check that each Markdown table has a consistent number of columns in its header, separator, and every data row.
- Check that raw samples use the documented columns/order and expected rows use the target-schema order.
- Check that absent JSON keys are distinct from explicit nulls.
- Check that all five headings appear once and in the required order, and that no stale JSONL sample blocks remain when samples are intended to be tables.
- Report the created file path and concise validation results.
- Do not commit or push anything unless I explicitly ask.
