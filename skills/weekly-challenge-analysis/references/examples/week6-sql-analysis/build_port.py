"""Builds Claude_gold_submit_Postgres.sql. Repeated per-column blocks are generated here so they cannot drift apart;
the output file is plain SQL (no functions)."""

FMT = "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'"
TZ_RE = r"'^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$'"
NAIVE_RE = r"'^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$'"
NULLS_BASIC = "'', 'NULL', '\\N', 'NONE', 'NAN', 'N/A', '-'"
NULLS_EXT = "'', 'NULL', '\\N', 'NONE', 'NAN', 'N/A', 'NA', '-', '--', 'NIL', 'UNDEFINED', '?', 'UNKNOWN'"


def nullif_basic(col, alias=None):
    """text column already trimmed -> NULL when it is a null marker"""
    return f"CASE WHEN upper({col}) IN ({NULLS_BASIC}) THEN NULL ELSE {col} END"


def prep(col, out, naive_is_utc=False):
    """step n: the text that will be parsed (gold: branches 4-10)."""
    last = col if naive_is_utc else f"{col} || '+08:00'"
    return f"""    CASE WHEN {col} IS NULL THEN NULL
         WHEN {col} ~ '^[0-9]+$' THEN NULL                                   -- all digits: epoch, handled in step p
         WHEN {col} LIKE '%:%' AND {col} ~ ':[0-9]{{2}}[+-][0-9]{{2}}$' THEN {col} || ':00'
         WHEN {col} LIKE '%:%' AND {col} ~ '[0-9][+-][0-9]{{4}}$' THEN left({col}, length({col}) - 2) || ':' || right({col}, 2)
         WHEN {col} LIKE '%:%' AND {col} ~ '[0-9][+-][0-9]{{2}}$' THEN {col} || ':00'
         WHEN {col} LIKE '%:%' AND {col} ~ '[0-9][+-][0-9]{{2}}:[0-9]{{2}}$' THEN {col}
         WHEN {col} LIKE '%:%' AND {col} ~ '[Zz]$' THEN {col}
         WHEN {col} LIKE '%:%' AND {col} ILIKE '% UTC' THEN replace({col}, ' UTC', '')
         ELSE {last} END AS {out}"""


def parse(col, s, out):
    """step p: text -> 'YYYY-MM-DDTHH:MM:SSZ' in UTC, or NULL."""
    return f"""    CASE WHEN {col} IS NULL THEN NULL
         WHEN {col} ~ '^[0-9]{{13}}$' THEN to_char(to_timestamp(({col}::bigint / 1000)::double precision) AT TIME ZONE 'UTC', {FMT})
         WHEN {col} ~ '^[0-9]{{10}}$' THEN to_char(to_timestamp({col}::bigint::double precision) AT TIME ZONE 'UTC', {FMT})
         WHEN {s} ~ {TZ_RE} AND pg_input_is_valid({s}, 'timestamptz')
              THEN to_char(date_trunc('second', {s}::timestamptz AT TIME ZONE 'UTC'), {FMT})
         WHEN {s} ~ {NAIVE_RE} AND pg_input_is_valid({s}, 'timestamp')
              THEN to_char(date_trunc('second', {s}::timestamp), {FMT})
         END AS {out}"""


def day(col, out):
    """SQLite date(x) on a text value -> 'YYYY-MM-DD' (UTC day) or NULL."""
    return f"""    CASE WHEN {col} ~ '^[0-9]{{4}}-[0-9]{{2}}-[0-9]{{2}}$' AND pg_input_is_valid({col}, 'date') THEN {col}
         WHEN {col} ~ {TZ_RE} AND pg_input_is_valid({col}, 'timestamptz') THEN to_char({col}::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD')
         WHEN {col} ~ {NAIVE_RE} AND pg_input_is_valid({col}, 'timestamp') THEN to_char({col}::timestamp, 'YYYY-MM-DD')
         END AS {out}"""


def sep(lines, indent=''):
    return ',\n'.join(lines)


HEADER = open('/home/claude/w6/header.sql').read()

# ------------------------------------------------------------------------------------------------
UNIT = f"""
-- task: unit_visit_history
-- Every distinct source row of the change log, cleaned, kept across runs because the landing
-- forgets after 7 nights. A row already held is skipped before any cleaning. Rows are never
-- collapsed here: each system fills only the columns it owns, so the day level and visit level
-- views below pick the newest non-null value of each column.
-- Steps: b = trim + row key, c = null markers -> NULL, n = text to parse, p = parse, k/q/bd = find booking_ref in text,
--        e = clean columns, d = booking_ref null markers + de-duplicate.
WITH b AS (
  SELECT r.src_key,
    btrim(r.visit_gkey, ' ') AS gk, btrim(r.unit_nbr, ' ') AS unit_raw, btrim(r.line_scac, ' ') AS scac,
    btrim(r.visit_state, ' ') AS st, btrim(r.tariff_cd, ' ') AS tcd, btrim(r.days_chg, ' ') AS days_t,
    btrim(r.dsch_time, ' ') AS d_at, btrim(r.gate_out_time, ' ') AS g_at, btrim(r.last_upd_time, ' ') AS u_at,
    btrim(r._batch_id, ' ') AS b_id, btrim(r._restated_day, ' ') AS rest, btrim(r._loaded_at, ' ') AS l_at,
    r.remarks
  FROM (
    SELECT u.*,
           COALESCE(u.visit_gkey, '') || '|' || COALESCE(u._batch_id, '') || '|' || COALESCE(u._restated_day, '') || '|' || COALESCE(u._loaded_at, '') || '|' || COALESCE(u.last_upd_time, '') || '|' || COALESCE(u.days_chg, '') || '|' || COALESCE(u.visit_state, '') || '|' || COALESCE(u.gate_out_time, '') || '|' || COALESCE(u.unit_nbr, '') AS src_key
    FROM unit_visit AS u
  ) AS r
{{% if is_incremental() %}}
  LEFT JOIN {{{{ this }}}} AS x ON x.src_key = r.src_key
  WHERE x.src_key IS NULL
{{% endif %}}
),
c AS (
  SELECT src_key, remarks,
{sep(['    ' + nullif_basic(c) + ' AS ' + a for c, a in [('gk','gk'),('unit_raw','unit_raw'),('scac','scac'),('st','st'),('tcd','tcd'),('days_t','days_t'),('d_at','d_at'),('g_at','g_at'),('u_at','u_at'),('b_id','b_id'),('rest','rest'),('l_at','l_at')]], '')}
  FROM b
),
n AS (
  SELECT c.*,
{prep('d_at','d_s')},
{prep('g_at','g_s')},
{prep('u_at','u_s')},
{prep('l_at','l_s', naive_is_utc=True)}
  FROM c
),
p AS (
  SELECT n.*,
{parse('d_at','d_s','dsch_utc')},
{parse('g_at','g_s','gate_utc')},
{parse('u_at','u_s','upd_utc')},
{parse('l_at','l_s','loaded_utc')},
{day('b_id','batch_day')},
{day('rest','rest_day')},
    CASE WHEN gk ~ '^[0-9]+$' THEN gk
         WHEN gk ~ '^[0-9]+\\.0$' THEN substr(gk, 1, length(gk) - 2) END AS visit_gkey,
    -- where the booking_ref key sits in the remarks text (used only when remarks is not valid JSON)
    CASE WHEN strpos(remarks, '"booking_ref"') > 0 THEN strpos(remarks, '"booking_ref"') + 13
         WHEN strpos(remarks, '"bookingRef"') > 0 THEN strpos(remarks, '"bookingRef"') + 12 END AS kpos
  FROM n
),
k AS (
  SELECT p.*,
         CASE WHEN kpos IS NOT NULL AND substr(ltrim(substr(remarks, kpos), ' '), 1, 1) = ':'
              THEN ltrim(substr(ltrim(substr(remarks, kpos), ' '), 2), ' ') END AS qv
  FROM p
  WHERE visit_gkey IS NOT NULL
),
bd AS (
  SELECT k.*, CASE WHEN substr(qv, 1, 1) = '"' THEN substr(qv, 2) END AS body,
         pg_input_is_valid(remarks, 'jsonb') AS remarks_ok
  FROM k
),
e AS (
  SELECT src_key, visit_gkey,
         upper(replace(replace(replace(replace(unit_raw, ' ', ''), '-', ''), '_', ''), '.', '')) AS unit_c,
         upper(scac) AS line_scac,
         lower(replace(replace(st, ' ', '_'), '-', '_')) AS state_norm,
         upper(tcd) AS tariff_cd,
         CASE WHEN days_t ~ '^-?([0-9]+\\.?[0-9]*|\\.[0-9]+)$' THEN days_t::numeric END AS days,
         dsch_utc, gate_utc, upd_utc, loaded_utc, batch_day, rest_day,
         CASE WHEN remarks_ok THEN COALESCE(
                 CASE jsonb_typeof(remarks::jsonb -> 'booking_ref') WHEN 'boolean' THEN CASE WHEN (remarks::jsonb ->> 'booking_ref') = 'true' THEN '1' ELSE '0' END
                      ELSE remarks::jsonb ->> 'booking_ref' END,
                 CASE jsonb_typeof(remarks::jsonb -> 'bookingRef') WHEN 'boolean' THEN CASE WHEN (remarks::jsonb ->> 'bookingRef') = 'true' THEN '1' ELSE '0' END
                      ELSE remarks::jsonb ->> 'bookingRef' END)
              WHEN strpos(body, '"') > 0 THEN substr(body, 1, strpos(body, '"') - 1) END AS ref_raw
  FROM bd
),
d AS (
  SELECT e.*,
         CASE WHEN unit_c ~ '^[A-Z]{{4}}[0-9]{{7}}$' THEN unit_c END AS unit_nbr,
         COALESCE(rest_day, batch_day, to_char(substr(loaded_utc, 1, 10)::date - 1, 'YYYY-MM-DD')) AS eff_day,
         CASE WHEN rest_day IS NOT NULL THEN 1 ELSE 0 END AS restated,
         CASE WHEN upper(btrim(ref_raw, ' ')) IN ({NULLS_EXT}) THEN NULL ELSE btrim(ref_raw, ' ') END AS booking_ref,
         row_number() OVER (PARTITION BY src_key ORDER BY loaded_utc COLLATE "C" DESC NULLS LAST) AS rn
  FROM e
)
SELECT src_key, visit_gkey, eff_day, batch_day, unit_nbr, line_scac, state_norm, tariff_cd, days,
       dsch_utc, gate_utc, upd_utc, loaded_utc, booking_ref, restated
FROM d
WHERE rn = 1 AND eff_day IS NOT NULL
"""

TARIFF = f"""
-- task: tariff_rate_history
-- One rate per tariff per effective day, kept across runs because the landing keeps 2 nights and
-- later nights carry only the changes. A rate sent again for the same day replaces the earlier one.
-- Steps: b = trim, c = null markers -> NULL, n = prepare text, p = parse, d = newest per tariff + day.
WITH b AS (
  SELECT btrim(tariff_cd, ' ') AS tariff_cd, btrim(eff_date, ' ') AS eff_date, btrim(rate_usd, ' ') AS rate_usd,
         btrim(_loaded_at, ' ') AS l_at
  FROM tariff_rate
),
c AS (
  SELECT {nullif_basic('tariff_cd')} AS tariff_cd,
         {nullif_basic('eff_date')} AS eff_date,
         {nullif_basic('rate_usd')} AS rate_usd,
         {nullif_basic('l_at')} AS l_at
  FROM b
),
n AS (
  SELECT c.*,
         -- decimal comma ("12,50") -> point; thousands comma ("1,234.50") dropped; currency sign dropped
         CASE WHEN rate_usd IS NULL THEN NULL
              WHEN rate_usd LIKE '%,%' AND rate_usd NOT LIKE '%.%' THEN replace(replace(rate_usd, ',', '.'), '$', '')
              ELSE replace(replace(rate_usd, ',', ''), '$', '') END AS rate_t,
{prep('l_at','l_s', naive_is_utc=True)}
  FROM c
),
p AS (
  SELECT upper(tariff_cd) AS tariff_cd,
{day('eff_date','eff_date')},
         rate_t,
{parse('l_at','l_s','loaded_utc')}
  FROM n
),
r AS (
  SELECT tariff_cd, eff_date, substring(rate_t from '^[0-9]+(?:\\.[0-9]*)?')::numeric AS rate_usd, loaded_utc
  FROM p
  WHERE rate_t ~ '^[0-9][0-9.]*$' AND tariff_cd IS NOT NULL AND eff_date IS NOT NULL
),
d AS (
  SELECT r.*, row_number() OVER (PARTITION BY tariff_cd, eff_date ORDER BY loaded_utc COLLATE "C" DESC NULLS LAST) AS rn FROM r
)
SELECT d.tariff_cd, d.eff_date, d.rate_usd, d.loaded_utc
FROM d
{{% if is_incremental() %}}
LEFT JOIN {{{{ this }}}} AS o ON o.tariff_cd = d.tariff_cd AND o.eff_date = d.eff_date
{{% endif %}}
WHERE d.rn = 1
{{% if is_incremental() %}}
  AND (o.tariff_cd IS NULL OR COALESCE(d.loaded_utc, '') COLLATE "C" >= COALESCE(o.loaded_utc, '') COLLATE "C")
{{% endif %}}
"""

LINE = f"""
-- task: line_operator_history
-- A shipping line row is stored when its bill-to party or test flag differs from the latest one
-- held. The landing keeps only the latest copy, so this is the only record of earlier states.
-- Steps: b = trim, c = null markers -> NULL, n = prepare text, p = parse, d = newest per line + day.
WITH b AS (
  SELECT btrim(line_scac, ' ') AS line_scac, btrim(_batch_id, ' ') AS b_id, btrim(bill_to, ' ') AS bill_to,
         btrim(test_flag, ' ') AS test_flag, btrim(_loaded_at, ' ') AS l_at
  FROM line_operator
),
c AS (
  SELECT {nullif_basic('line_scac')} AS line_scac,
         {nullif_basic('b_id')} AS b_id,
         {nullif_basic('bill_to')} AS bill_to,
         {nullif_basic('test_flag')} AS test_flag,
         {nullif_basic('l_at')} AS l_at
  FROM b
),
n AS (
  SELECT c.*,
{prep('l_at','l_s', naive_is_utc=True)}
  FROM c
),
m AS (
  SELECT upper(line_scac) AS line_scac,
{day('b_id','snap_day')},
         CASE WHEN upper(bill_to) IN ({NULLS_EXT}) THEN NULL ELSE upper(bill_to) END AS bill_to,
         CASE WHEN upper(test_flag) IN ('Y', 'YES', 'TRUE', '1', 'T') THEN 1
              WHEN upper(test_flag) IN ('N', 'NO', 'FALSE', '0', 'F') THEN 0 END AS is_test,
{parse('l_at','l_s','loaded_utc')}
  FROM n
),
d AS (
  SELECT line_scac, snap_day, bill_to, is_test,
         row_number() OVER (PARTITION BY line_scac, snap_day ORDER BY loaded_utc COLLATE "C" DESC NULLS LAST) AS rn
  FROM m
  WHERE line_scac IS NOT NULL AND snap_day IS NOT NULL
){{% if is_incremental() %}},
cur AS (
  SELECT line_scac, bill_to, is_test FROM (
    SELECT line_scac, bill_to, is_test,
           row_number() OVER (PARTITION BY line_scac ORDER BY snap_day COLLATE "C" DESC) AS rk
    FROM {{{{ this }}}}
  ) AS ranked WHERE rk = 1
){{% endif %}}
SELECT d.line_scac, d.snap_day, d.bill_to, d.is_test
FROM d
{{% if is_incremental() %}}
LEFT JOIN cur AS c ON c.line_scac = d.line_scac
{{% endif %}}
WHERE d.rn = 1
{{% if is_incremental() %}}
  AND (c.line_scac IS NULL OR c.bill_to IS DISTINCT FROM d.bill_to OR c.is_test IS DISTINCT FROM d.is_test)
{{% endif %}}
"""


def maxkey(valcol):
    return (f"max(CASE WHEN {valcol} IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || "
            f"COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || {valcol} END COLLATE \"C\")")


REST = f"""
-- task: visits_latest
-- One row per visit. Each column is the newest non-null value over all the rows of the visit, in
-- order of the yard update time (a real instant), then batch day, then load time. One pass: the
-- value is carried behind a fixed-width 50 character sort key and cut off again after the max.
WITH g AS (
  SELECT visit_gkey, min(eff_day COLLATE "C") AS first_day,
         {maxkey('unit_nbr')} AS m_unit,
         {maxkey('line_scac')} AS m_line,
         {maxkey('state_norm')} AS m_state,
         {maxkey('tariff_cd')} AS m_tariff,
         {maxkey('dsch_utc')} AS m_dsch,
         {maxkey('gate_utc')} AS m_gate,
         {maxkey('booking_ref')} AS m_book
  FROM unit_visit_history
  GROUP BY visit_gkey
),
v AS (
  SELECT visit_gkey, first_day,
         substr(m_unit, 51) AS unit_nbr, substr(m_line, 51) AS line_scac, substr(m_state, 51) AS state_v,
         substr(m_tariff, 51) AS tariff_cd, substr(m_dsch, 51) AS dsch_utc, substr(m_gate, 51) AS gate_out_time,
         substr(m_book, 51) AS booking_ref
  FROM g
)
SELECT visit_gkey, first_day, unit_nbr, line_scac,
       CASE state_v
         WHEN 'discharged' THEN 'discharged' WHEN 'discharge' THEN 'discharged' WHEN 'dischgd' THEN 'discharged'
         WHEN 'dischd' THEN 'discharged' WHEN 'disch' THEN 'discharged' WHEN 'unloaded' THEN 'discharged'
         WHEN 'held' THEN 'held' WHEN 'hold' THEN 'held' WHEN 'on_hold' THEN 'held' WHEN 'holding' THEN 'held'
         WHEN 'gated_out' THEN 'gated_out' WHEN 'gate_out' THEN 'gated_out' WHEN 'gatedout' THEN 'gated_out'
         WHEN 'gateout' THEN 'gated_out' WHEN 'gated' THEN 'gated_out' WHEN 'exited' THEN 'gated_out'
         WHEN 'exit' THEN 'gated_out' WHEN 'departed' THEN 'gated_out' WHEN 'out' THEN 'gated_out'
         WHEN 'transshipped' THEN 'transshipped' WHEN 'transhipped' THEN 'transshipped'
         WHEN 'transshipment' THEN 'transshipped' WHEN 'transship' THEN 'transshipped'
         WHEN 'tranship' THEN 'transshipped' WHEN 'trans' THEN 'transshipped' WHEN 'ts' THEN 'transshipped'
       END AS visit_state,
       tariff_cd, dsch_utc, gate_out_time, booking_ref
FROM v

-- task: visit_lines
-- Per visit: the bill-to party and test flag of its line on the terminal day it came off the ship.
-- The terminal day runs from 06:00 to 06:00 at UTC+8, which is the UTC clock shifted by 2 hours.
-- The stored state of the line on or before that day is used, else the earliest stored state.
WITH base AS (
  SELECT visit_gkey, line_scac,
         COALESCE(to_char(substr(dsch_utc, 1, 19)::timestamp + interval '2 hours', 'YYYY-MM-DD'), first_day) AS d
  FROM visits_latest
  WHERE line_scac IS NOT NULL
),
snaps AS (
  SELECT line_scac, snap_day AS d, 0 AS ord, NULL::text AS visit_gkey
  FROM line_operator_history
  WHERE line_scac IN (SELECT line_scac FROM base)
),
evs AS (SELECT line_scac, d, 1 AS ord, visit_gkey FROM base),
u AS (SELECT * FROM snaps UNION ALL SELECT * FROM evs),
w AS (
  SELECT line_scac, d, ord, visit_gkey,
         max(CASE WHEN ord = 0 THEN d END COLLATE "C")
           OVER (PARTITION BY line_scac ORDER BY d COLLATE "C", ord ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS asof_d,
         min(CASE WHEN ord = 0 THEN d END COLLATE "C") OVER (PARTITION BY line_scac) AS first_d
  FROM u
)
SELECT w.visit_gkey, s.bill_to, s.is_test
FROM w
LEFT JOIN line_operator_history AS s
       ON s.line_scac = w.line_scac AND s.snap_day = COALESCE(w.asof_d, w.first_d)
WHERE w.ord = 1

-- task: visit_days
-- One row per visit per charge day: the days charged and the tariff of that day. A restated day
-- (a row marked as restating it) wins over the rows it restates, so the day is replaced and not
-- added twice; otherwise the newest non-null value of the day is taken. The tariff of a row that
-- carries none is the latest tariff of the visit. One pass over the history.
-- days is carried as text like SQLite prints a REAL (3.0, 1.5, -2.0) so the tie-break between rows with the same time is the same.
WITH g AS (
  SELECT visit_gkey, eff_day,
         max(CASE WHEN days IS NOT NULL THEN restated::text || COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') ||
                   CASE WHEN days = trunc(days) THEN trunc(days)::bigint::text || '.0' ELSE trim_scale(days)::text END END COLLATE "C") AS m_days,
         max(CASE WHEN tariff_cd IS NOT NULL THEN restated::text || COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || tariff_cd END COLLATE "C") AS m_tariff
  FROM unit_visit_history
  GROUP BY visit_gkey, eff_day
)
SELECT g.visit_gkey, g.eff_day,
       substr(g.m_days, 42)::numeric AS days,
       COALESCE(substr(g.m_tariff, 42), l.tariff_cd) AS tariff_cd
FROM g
LEFT JOIN visits_latest AS l ON l.visit_gkey = g.visit_gkey
WHERE g.m_days IS NOT NULL

-- task: visit_charges
-- Per visit: the days charged each day at the rate of that day, added up, and the part charged on
-- days up to the close. Amounts are integers in ten-thousandths of a dollar.
SELECT d.visit_gkey,
       sum(round(d.days * r.rate_i)::bigint)::bigint AS tot_i,
       sum(CASE WHEN d.eff_day <= '2026-10-19' THEN round(d.days * r.rate_i)::bigint ELSE 0 END)::bigint AS per_i
FROM visit_days AS d
LEFT JOIN tariff_day_rates AS r ON r.tariff_cd = d.tariff_cd AND r.day = d.eff_day
GROUP BY d.visit_gkey

-- task: tariff_day_rates
-- USD per charged day, in ten-thousandths, for each tariff and day a visit needs: the rate of the
-- latest effective day on or before it, so a rate applies until the next one starts.
WITH pairs AS (
  SELECT DISTINCT tariff_cd, eff_day AS day FROM visit_days WHERE tariff_cd IS NOT NULL
)
SELECT p.tariff_cd, p.day,
       (SELECT round(t.rate_usd * 10000)::bigint FROM tariff_rate_history AS t
        WHERE t.tariff_cd = p.tariff_cd AND t.eff_date COLLATE "C" <= p.day COLLATE "C"
        ORDER BY t.eff_date COLLATE "C" DESC LIMIT 1) AS rate_i
FROM pairs AS p

-- task: storage_charges
-- The target: one row per visit, visits of a test line left out. Amounts are rounded half away
-- from zero to cents in integer arithmetic (tot_i and per_i are bigint, so "/" is integer division).
SELECT v.visit_gkey,
       v.unit_nbr,
       v.visit_state,
       v.gate_out_time,
       v.booking_ref,
       ((CASE WHEN COALESCE(c.tot_i, 0) < 0 THEN -((-COALESCE(c.tot_i, 0) + 50) / 100) ELSE (COALESCE(c.tot_i, 0) + 50) / 100 END) / 100.0)::numeric(20, 2)::text AS storage_usd,
       ((CASE WHEN COALESCE(c.per_i, 0) < 0 THEN -((-COALESCE(c.per_i, 0) + 50) / 100) ELSE (COALESCE(c.per_i, 0) + 50) / 100 END) / 100.0)::numeric(20, 2)::text AS storage_in_period_usd,
       l.bill_to
FROM visits_latest AS v
LEFT JOIN visit_charges AS c ON c.visit_gkey = v.visit_gkey
LEFT JOIN visit_lines AS l ON l.visit_gkey = v.visit_gkey
WHERE COALESCE(l.is_test, 0) = 0
"""

out = HEADER + UNIT + '\n' + TARIFF + '\n' + LINE + '\n' + REST
open('/home/claude/w6/Claude_gold_submit_Postgres.sql', 'w').write(out)
print(len(out.splitlines()), 'lines')
