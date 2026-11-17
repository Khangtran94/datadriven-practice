-- Week 09 | PostgreSQL companion translation of gold_submit.sql
-- Source dialect: SQLite-oriented DataDriven SQL (including its regexp_replace helper surface).
-- Target: PostgreSQL 16+; uses pg_input_is_valid(text, type_name). No extensions required.
--
-- This file contains the four SQL task queries only. The source DAG's scheduling,
-- insert_overwrite/merge materialization, partition replacement, dependencies, and
-- trigger behavior remain the responsibility of the DataDriven orchestration runner.
-- In particular, PostgreSQL alone does not execute the DAG configuration.
--
-- Timestamp convention: source timestamps without an explicit offset are interpreted
-- as UTC, matching the challenge's UTC event-time convention. Set the session zone
-- explicitly so timestamptz input casts have deterministic behavior.
--
-- Validation status: static translation/review only. No PostgreSQL runtime or sample
-- dataset was available in this run; execution and sample-output comparison remain
-- outstanding. Review numeric/timestamp edge cases against the runner before use.

SET TIME ZONE 'UTC';

-- task: events_hist
SELECT DISTINCT *
FROM order_events;

-- task: scans_hist
SELECT DISTINCT *
FROM scans;

-- task: prices_hist
SELECT DISTINCT *
FROM prices;

-- task: order_charges
WITH ev0 AS (
    SELECT DISTINCT
        event_id::text AS event_id,
        order_id::text AS order_id,
        event::text AS event,
        event_at::text AS event_at,
        detail::text AS detail,
        written_at::text AS written_at
    FROM events_hist
),
ev1 AS (
    SELECT
        event_id,
        btrim(order_id) AS o1,
        lower(regexp_replace(coalesce(event, ''), '[^A-Za-z]', '', 'g')) AS e,
        regexp_replace(
            regexp_replace(
                regexp_replace(
                    replace(replace(btrim(coalesce(event_at, '')), ' UTC', 'Z'), 'T', ' '),
                    '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$',
                    E'\\1\\3:00'
                ),
                '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})([0-9]{2})$',
                E'\\1\\3:\\4'
            ),
            '^([0-9]{2})/([0-9]{2})/([0-9]{4})',
            E'\\3-\\1-\\2'
        ) AS s,
        regexp_replace(
            replace(btrim(coalesce(written_at, '')), 'T', ' '),
            '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$',
            E'\\1\\3:00'
        ) AS ws,
        btrim(detail) AS detail
    FROM ev0
),
ev AS (
    SELECT
        event_id,
        e,
        detail,
        right(
            '00000000' ||
            regexp_replace(
                CASE
                    WHEN strpos(o1, '.') > 0 THEN substr(o1, 1, strpos(o1, '.') - 1)
                    ELSE o1
                END,
                '[^0-9]', '', 'g'
            ),
            8
        ) AS oid,
        CASE
            WHEN s <> ''
             AND regexp_replace(s, '[0-9]', '', 'g') = ''
             AND length(s) = 13
                THEN to_timestamp(s::numeric / 1000.0) AT TIME ZONE 'UTC'
            WHEN s <> ''
             AND regexp_replace(s, '[0-9]', '', 'g') = ''
             AND length(s) BETWEEN 9 AND 10
                THEN to_timestamp(s::numeric) AT TIME ZONE 'UTC'
            WHEN s <> '' AND pg_input_is_valid(s, 'timestamptz')
                THEN s::timestamptz AT TIME ZONE 'UTC'
            ELSE NULL
        END AS ts,
        CASE
            WHEN ws <> '' AND pg_input_is_valid(ws, 'timestamptz')
                THEN to_char(ws::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US')
            ELSE ws
        END AS wts
    FROM ev1
),
evn AS (
    SELECT
        *,
        CASE
            WHEN e LIKE '%replac%' OR e LIKE '%substitut%' THEN
                CASE
                    WHEN e LIKE '%declin%' OR e LIKE '%reject%' OR e LIKE '%deni%' OR e LIKE '%refus%' THEN 'rdec'
                    WHEN e LIKE '%approv%' OR e LIKE '%accept%' OR e LIKE '%confirm%' THEN 'rapp'
                END
            WHEN e LIKE '%uncancel%' OR e LIKE '%reinstat%' OR e LIKE '%restor%' OR e LIKE '%reopen%' OR e LIKE '%reactiv%' THEN 'reinstated'
            WHEN e LIKE '%cancel%' THEN 'cancelled'
            WHEN e LIKE '%delet%' OR e LIKE '%remov%' OR e LIKE '%purg%' THEN 'deleted'
            WHEN e LIKE '%tip%' THEN 'tip'
            WHEN e LIKE '%deliver%' OR e LIKE '%dropoff%' OR e LIKE '%dropped%' OR e LIKE '%complet%' THEN 'delivered'
            WHEN e LIKE '%plac%' OR e LIKE '%creat%' OR e LIKE '%submit%' OR e = 'new' OR e LIKE '%neworder%' THEN 'placed'
        END AS k
    FROM ev
),
ranked AS (
    SELECT
        *,
        row_number() OVER (
            PARTITION BY oid,
                CASE
                    WHEN k IN ('cancelled', 'reinstated') THEN 'cr'
                    WHEN k IN ('placed', 'tip') THEN 'tp'
                    ELSE k
                END
            ORDER BY ts DESC, wts DESC, event_id DESC
        ) AS rn
    FROM evn
),
orders AS (
    SELECT
        oid,
        min(CASE WHEN k = 'placed' THEN ts END) AS placed_at,
        max(CASE WHEN k = 'deleted' THEN 1 ELSE 0 END) AS is_del,
        min(CASE WHEN k = 'delivered' THEN ts END) AS delivered_ts,
        max(CASE WHEN k IN ('cancelled', 'reinstated') AND rn = 1 THEN k END) AS last_cr,
        max(CASE WHEN k IN ('placed', 'tip') AND rn = 1 THEN detail END) AS tip_txt
    FROM ranked
    GROUP BY oid
),
ord AS (
    SELECT *
    FROM orders
    WHERE is_del = 0
      AND placed_at >= timestamp '2026-10-16 00:00:00'
      AND placed_at <  timestamp '2026-11-15 00:00:00'
),
repl AS (
    SELECT detail AS scan_id, k
    FROM (
        SELECT
            detail,
            k,
            row_number() OVER (
                PARTITION BY detail
                ORDER BY ts DESC, wts DESC, event_id DESC
            ) AS rn
        FROM evn
        WHERE k IN ('rdec', 'rapp')
    ) AS replacement_events
    WHERE rn = 1
),
sc1 AS (
    SELECT DISTINCT
        btrim(scan_id::text) AS scan_id,
        order_id::text AS order_id,
        code::text AS code,
        qty::text AS qty,
        weight_lb::text AS weight_lb,
        regexp_replace(coalesce(_batch_id::text, ''), '[^0-9]', '', 'g') AS bday,
        CASE
            WHEN pg_input_is_valid(
                regexp_replace(
                    replace(btrim(_loaded_at::text), 'T', ' '),
                    '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$',
                    E'\\1\\3:00'
                ),
                'timestamptz'
            )
            THEN regexp_replace(
                replace(btrim(_loaded_at::text), 'T', ' '),
                '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$',
                E'\\1\\3:00'
            )::timestamptz AT TIME ZONE 'UTC'
        END AS lts
    FROM scans_hist
),
sc2 AS (
    SELECT *
    FROM (
        SELECT
            *,
            max(lts) OVER (PARTITION BY bday) AS mlts
        FROM sc1
    ) AS scan_versions
    WHERE lts = mlts
),
sc AS (
    SELECT
        scan_id,
        right(
            '00000000' ||
            regexp_replace(
                CASE
                    WHEN strpos(btrim(order_id), '.') > 0
                        THEN substr(btrim(order_id), 1, strpos(btrim(order_id), '.') - 1)
                    ELSE btrim(order_id)
                END,
                '[^0-9]', '', 'g'
            ),
            8
        ) AS oid,
        regexp_replace(coalesce(code, ''), '[^0-9]', '', 'g') AS code_raw,
        CASE
            WHEN regexp_replace(coalesce(qty, ''), '[^0-9]', '', 'g') <> ''
             AND regexp_replace(qty, '[^0-9.-]', '', 'g') ~ '^-?([0-9]+(\.[0-9]*)?|\.[0-9]+)$'
                THEN regexp_replace(qty, '[^0-9.-]', '', 'g')::double precision
        END AS q,
        CASE
            WHEN regexp_replace(coalesce(weight_lb, ''), '[^0-9]', '', 'g') <> ''
             AND regexp_replace(weight_lb, '[^0-9.-]', '', 'g') ~ '^-?([0-9]+(\.[0-9]*)?|\.[0-9]+)$'
                THEN regexp_replace(weight_lb, '[^0-9.-]', '', 'g')::double precision
        END AS w
    FROM sc2
    WHERE scan_id NOT IN (SELECT scan_id FROM repl WHERE k = 'rdec')
),
scn AS (
    SELECT
        *,
        CASE
            WHEN length(code_raw) = 13 AND code_raw LIKE '0%' THEN substr(code_raw, 2)
            ELSE code_raw
        END AS code12,
        ltrim(code_raw, '0') AS ckey
    FROM sc
),
pr0 AS (
    SELECT DISTINCT
        ltrim(regexp_replace(coalesce(code::text, ''), '[^0-9]', '', 'g'), '0') AS ckey,
        CASE
            WHEN regexp_replace(coalesce(price::text, ''), '[^0-9.-]', '', 'g') ~ '^-?([0-9]+(\.[0-9]*)?|\.[0-9]+)$'
                THEN round(regexp_replace(price::text, '[^0-9.-]', '', 'g')::numeric * 100)::integer
        END AS pc,
        CASE
            WHEN lower(coalesce(sold_by::text, '')) LIKE '%lb%'
              OR lower(coalesce(sold_by::text, '')) LIKE '%pound%' THEN 'lb'
            ELSE 'each'
        END AS sb,
        CASE
            WHEN pg_input_is_valid(
                regexp_replace(
                    replace(btrim(_loaded_at::text), 'T', ' '),
                    '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$',
                    E'\\1\\3:00'
                ),
                'timestamptz'
            )
            THEN regexp_replace(
                replace(btrim(_loaded_at::text), 'T', ' '),
                '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$',
                E'\\1\\3:00'
            )::timestamptz AT TIME ZONE 'UTC'
        END AS lts
    FROM prices_hist
),
pr1 AS (
    SELECT
        *,
        lag(pc) OVER (PARTITION BY ckey ORDER BY lts) AS ppc,
        lag(sb) OVER (PARTITION BY ckey ORDER BY lts) AS psb,
        row_number() OVER (PARTITION BY ckey ORDER BY lts) AS first_rn
    FROM pr0
),
pr AS (
    SELECT ckey, pc, sb, lts
    FROM pr1
    WHERE first_rn = 1 OR ppc <> pc OR psb <> sb
),
items AS (
    SELECT
        s.oid,
        s.scan_id,
        s.code12,
        s.q,
        s.w,
        s.ckey,
        o.placed_at,
        row_number() OVER (
            PARTITION BY s.oid, s.scan_id, s.code12, s.q, s.w
            ORDER BY
                CASE WHEN p.lts <= o.placed_at THEN 0 ELSE 1 END,
                CASE WHEN p.lts <= o.placed_at THEN p.lts END DESC,
                p.lts
        ) AS prn,
        p.pc,
        p.sb
    FROM scn AS s
    JOIN ord AS o ON o.oid = s.oid
    LEFT JOIN pr AS p ON p.ckey = s.ckey
),
line AS (
    SELECT
        oid,
        q,
        w,
        CASE
            WHEN length(code12) = 12 AND code12 LIKE '2%' THEN 'label'
            ELSE sb
        END AS sb,
        CASE
            WHEN length(code12) = 12 AND code12 LIKE '2%' THEN substr(code12, 7, 5)::integer
            ELSE pc
        END AS pc
    FROM items
    WHERE prn = 1
),
agg AS (
    SELECT
        oid,
        sum(
            CASE
                WHEN sb = 'lb' THEN
                    CASE
                        WHEN coalesce(w, q) < 0 THEN -1
                        WHEN coalesce(w, q) > 0 THEN 1
                        ELSE 0
                    END
                ELSE coalesce(q, 0)
            END
        ) AS n,
        sum(
            CASE
                WHEN sb = 'lb'
                    THEN round((coalesce(w, q) * pc + 0.000001)::numeric)::integer
                ELSE round((coalesce(q, 0) * pc + 0.000001)::numeric)::integer
            END
        ) AS cents
    FROM line
    GROUP BY oid
)
SELECT
    o.oid AS order_id,
    CASE WHEN o.last_cr = 'cancelled' THEN 'cancelled' ELSE 'delivered' END AS status,
    CASE
        WHEN o.last_cr = 'cancelled' OR o.delivered_ts IS NULL THEN NULL
        ELSE to_char(o.delivered_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    END AS delivered_at,
    CASE
        WHEN o.last_cr = 'cancelled' THEN 0
        ELSE round(coalesce(a.n, 0))::integer
    END AS items,
    CASE
        WHEN o.last_cr = 'cancelled' THEN 0.0
        ELSE round(coalesce(a.cents, 0)::numeric / 100.0, 2)
    END AS subtotal,
    CASE
        WHEN o.last_cr = 'cancelled' THEN 0.0
        ELSE round(
            coalesce(
                CASE
                    WHEN tv.tip_num ~ '^-?([0-9]+(\.[0-9]*)?|\.[0-9]+)$'
                        THEN tv.tip_num::numeric
                END,
                0
            ),
            2
        )
    END AS tip
FROM ord AS o
LEFT JOIN agg AS a ON a.oid = o.oid
LEFT JOIN LATERAL (
    SELECT regexp_replace(coalesce(o.tip_txt, ''), '[^0-9.-]', '', 'g') AS tip_num
) AS tv ON TRUE;
