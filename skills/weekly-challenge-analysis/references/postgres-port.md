# Porting a SQLite gold_submit.sql to PostgreSQL

Lessons from Week 5 (`the-close`). The gold was SQLite; the port matched it exactly on synthetic data (3 seeds,
about 6k payment rows, all 3 history tables plus `fct_payments`).

## Function and syntax map

| SQLite | PostgreSQL |
|---|---|
| `quote(x)` | `quote_nullable(x)` (text differs when x has a backslash; only used as a row key, so compare distinct counts, not text) |
| `trim(x, chars)`, `char(9,10,13)` | `btrim(x, E' \t\n\r')` (use `E''` for escapes; a plain `'\n'` is backslash + n, which is exactly the `\N` null marker some tools write) |
| `x GLOB 'pat'` | `x ~ '^regex$'` (`?` is `.`, `*` is `.*`, anchor with `^` and `$`) |
| `instr(a, b)` | `strpos(a, b)` |
| `substr('000000'\|\|x, -6)` | `lpad(x, 6, '0')` |
| `datetime(x)`, `date(x)` | regex shape check + `pg_input_is_valid(x, 'timestamp'/'timestamptz'/'date')` + cast |
| `datetime(n, 'unixepoch')` | `to_timestamp(n) AT TIME ZONE 'UTC'` |
| `json_valid`, `json_extract`, `json_type` | `pg_input_is_valid(x, 'jsonb')`, `->`, `->>`, `jsonb_typeof` (`integer`/`real` become `number`, `text` becomes `string`) |
| `max(k \|\| v)` + `substr(...)` | `(array_agg(v ORDER BY k DESC))[1]`, add `FILTER (WHERE v IS NOT NULL)` for "newest non-null" |
| median with `row_number()` | `percentile_disc(0.5) WITHIN GROUP (ORDER BY v)` (same lower median) |
| `CAST(x AS REAL)` money | `numeric` (exact), so the `+/- 1e-9` rounding nudge is not needed |

## Behaviors that differ silently

- **NULL ordering.** SQLite treats NULL as smallest, so `ORDER BY x DESC` puts NULL last. Postgres puts NULL first. Write `DESC NULLS LAST`.
- **Text tie-breaks.** SQLite compares text bytewise. Use `COLLATE "C"` on a text column used as a tie-break.
- **Casts raise.** `'abc'::timestamp` aborts the whole task; SQLite returns NULL. Gate every cast with a regex and `pg_input_is_valid()`. Also gate on shape, because Postgres accepts words like `now` and `today`.
- **Evaluation order.** `AND` operands may be evaluated in any order. Put a cast that can fail inside a nested `CASE`, or behind `pg_input_is_valid()` which never raises.
- **Time zones.** Do not depend on the session time zone. With an explicit offset use `::timestamptz AT TIME ZONE 'UTC'`; with none, the value is already UTC, so cast to plain `::timestamp`.
- **Fractional seconds.** SQLite `datetime()` truncates them. Use `date_trunc('second', ...)`.
- **Engine quirks, Postgres is stricter.** SQLite reads a bare `'12:30'` as `2000-01-01 12:30:00` and `date('2026-02-30')` as 2026-03-02. Postgres returns NULL for both. Keep such strings out of the synthetic data and mention it.
- **Double-encoded JSON.** A JSON string that holds JSON: if `jsonb_typeof(x::jsonb) = 'string'` and `(x::jsonb #>> '{}')` is valid JSON, unwrap it once.
- **Cut JSON.** A value cut at the column width is not JSON; the gold falls back to text search for the key. Keep that branch.

## Testing recipe

See `examples/week5-postgres-port/`. Steps: build raw tables as all-TEXT in both engines from one generator, run the gold tasks in
SQLite (`CREATE TABLE <task> AS <select>` per `-- task:` block), run the port in Postgres the same way, compare each table
(ignore `rk`, compare its distinct count), compare the final table per key and per column with zero tolerance, repeat for 3 seeds,
and check that the final columns are not mostly NULL (otherwise the test proves nothing).

## Added in Week 6 (the-dwell)

- **`substring(x from 'regex')` returns the parenthesized group**, not the whole match. Use a non-capturing group `(?:...)`.
  Symptom: a number parsed from text comes back as 0 or NULL.
- **psycopg2 treats `%` as a placeholder** whenever args are passed, so `LIKE '%:%'` fails with "tuple index out of range".
  Call `execute(sql, None)` when there are no parameters.
- **Timestamps kept as text**: compare, `ORDER BY` and `max()` them with `COLLATE "C"` (SQLite compares bytes). The `max(key || value)` + `substr` trick
  can stay as is in Postgres if the key is fixed width.
- **`sum(bigint)` is numeric in Postgres**: cast back to bigint when the next step relies on integer division.
- **SQLite prints REAL as `3.0`, `1.5`**: when a REAL is glued into a sort key, emulate it (`trunc(x)::bigint::text || '.0'`, `trim_scale(x)::text`) so ties break the same way.
- **SQLite trim(x) trims spaces only**; use `btrim(x, ' ')`, not `btrim(x)` with tabs and newlines unless the gold passes them.
- **Incremental markers** (`{% if is_incremental() %}`, `{{ this }}`) stay in the port unchanged. Postgres needs an alias on a subquery in FROM; SQLite does not.
- **Postgres cluster may stop between tool calls in the sandbox**: `pg_ctlcluster 16 main start` before each test run.
