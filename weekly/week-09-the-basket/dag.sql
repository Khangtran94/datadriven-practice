/* dag.yml
dag: the_basket
schedule: "0 */5 * * *" 
tasks:
  normalize_order:
    materialized: incremental
    depends_on: [order_events]
    incremental_strategy: merge
    unique_key: ['event_id']
  order_events_history:
    materialized: incremental
    depends_on: [normalize_order]
    incremental_strategy: merge
    unique_key: ['event_id']

  normalize_scan:
    materialized: incremental
    depends_on: [scans]
    incremental_strategy: merge
    unique_key: ['scan_id']
  scans_history:
    materialized: incremental
    depends_on: [normalize_scan]
    incremental_strategy: merge
    unique_key: ['scan_id']

  normalize_price:
    materialized: incremental
    depends_on: [prices]
    incremental_strategy: merge
    unique_key: ['code', 'loaded_at_utc']
  prices_history:
    materialized: incremental
    depends_on: [normalize_price]
    incremental_strategy: merge
    unique_key: ['code', 'loaded_at_utc']

  order_charges:
    materialized: table
    depends_on: [order_events_history, scans_history, prices_history]
*/

-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after

-- task: order_events_history
SELECT event_id,
       order_id,
       canonical_event AS event_name,
       event_at_utc    AS event_time,
       detail_tip,
       replacement_scan_id,
       written_at_utc  AS written_at
FROM normalize_order

-- task: scans_history
SELECT scan_id,
       order_id,
       code,
       qty,
       weight_lb,
       batch_id,
       loaded_at_utc
FROM normalize_scan
{% if is_incremental() %}
WHERE batch_id IS NULL
   OR batch_id NOT IN (SELECT batch_id FROM {{ this }} WHERE batch_id IS NOT NULL)
{% endif %}

-- task: prices_history
SELECT code, price, sold_by, loaded_at_utc
FROM normalize_price

-- task: normalize_scan
WITH t AS (
SELECT
    NULLIF(trim(scan_id,   ' ' || char(9) || char(10) || char(13)), '') AS scan_id,
    NULLIF(trim(order_id,  ' ' || char(9) || char(10) || char(13)), '') AS order_id,
    CASE WHEN lower(trim(code, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nan', 'n/a', '(null)', '<null>')
         THEN NULL ELSE trim(code, ' ' || char(9) || char(10) || char(13)) END AS code,
    NULLIF(trim(qty,       ' ' || char(9) || char(10) || char(13)), '') AS qty,
    NULLIF(trim(weight_lb, ' ' || char(9) || char(10) || char(13)), '') AS weight_lb,
    NULLIF(trim(_batch_id, ' ' || char(9) || char(10) || char(13)), '') AS _batch_id,
    NULLIF(trim(_loaded_at,' ' || char(9) || char(10) || char(13)), '') AS _loaded_at
FROM scans
{% if is_incremental() %}
-- days already stored are never re-read: the first-sent version of a day wins
WHERE _batch_id NOT IN (SELECT batch_id FROM {{ this }} WHERE batch_id IS NOT NULL)
{% endif %}
),
    
normalized AS (
SELECT
    CASE
        WHEN lower(trim(scan_id, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(scan_id, ' ' || char(9) || char(10) || char(13))
    END AS scan_id,

    CASE
        WHEN lower(trim(order_id, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(order_id, ' ' || char(9) || char(10) || char(13))
    END AS order_id,

    CASE
        WHEN lower(trim(code, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(code, ' ' || char(9) || char(10) || char(13))
    END AS code,

    CASE
        WHEN lower(trim(qty, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(qty, ' ' || char(9) || char(10) || char(13))
    END AS qty,

    CASE
        WHEN lower(trim(weight_lb, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(weight_lb, ' ' || char(9) || char(10) || char(13))
    END AS weight_lb,

    CASE
        WHEN lower(trim(_batch_id, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(_batch_id, ' ' || char(9) || char(10) || char(13))
    END AS _batch_id,

    CASE
        WHEN lower(trim(_loaded_at, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(_loaded_at, ' ' || char(9) || char(10) || char(13))
    END AS _loaded_at

FROM t),

parsed AS (
SELECT
    CASE
        WHEN regexp_like(lower(scan_id), '^[0-9a-f]{12}$')
        THEN lower('sc_' || scan_id)
        WHEN regexp_like(lower(scan_id), '^sc[_ /]*[0-9a-f]{12}$')
        THEN lower('sc_' || substr(scan_id, length(scan_id) - 11, 12))
        ELSE NULL
    END AS scan_id,

    CASE
        WHEN regexp_like(order_id, '^[0-9]{1,8}$')
        THEN substr('00000000' || order_id, length('00000000' || order_id) - 7, 8)
        ELSE NULL
    END AS order_id,

    code,

    CASE
        WHEN regexp_like(qty, '^[0-9]+([.][0-9]+)?$')
        THEN CAST(qty AS DECIMAL(18, 6))
        ELSE NULL
    END AS qty,

    CASE
        WHEN regexp_like(weight_lb, '^[0-9]+([.][0-9]+)?$')
        THEN CAST(weight_lb AS DECIMAL(18, 6))
        ELSE NULL
    END AS weight_lb,

    CASE
        WHEN regexp_like(_batch_id, '^[0-9]{8}$')
        THEN substr(_batch_id, 1, 4) || '-' || substr(_batch_id, 5, 2) || '-' || substr(_batch_id, 7, 2)
        WHEN regexp_like(_batch_id, '^[0-9]{4}/[0-9]{2}/[0-9]{2}$')
        THEN replace(_batch_id, '/', '-')
        WHEN regexp_like(_batch_id, '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
        THEN _batch_id
        WHEN regexp_like(_batch_id, '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}$')
        THEN substr(_batch_id, 1, 10)
        ELSE NULL
    END AS batch_id,

    _loaded_at,
    CASE
        WHEN _loaded_at IS NULL
        THEN NULL
        WHEN regexp_like(_loaded_at, '^[0-9]{16}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(_loaded_at AS REAL) / 1000000.0, 'unixepoch')
        WHEN regexp_like(_loaded_at, '^[0-9]{13}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(_loaded_at AS REAL) / 1000.0, 'unixepoch')
        WHEN regexp_like(_loaded_at, '^[0-9]{10}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(_loaded_at AS REAL), 'unixepoch')
        WHEN regexp_like(_loaded_at, '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(_loaded_at, 1, length(_loaded_at) - 3) || substr(_loaded_at, length(_loaded_at) - 2, 3) || ':00')
        ELSE strftime('%Y-%m-%dT%H:%M:%SZ', _loaded_at)
    END AS loaded_at_utc
FROM normalized),

dedup AS (
SELECT parsed.*,
       MIN(loaded_at_utc) OVER (PARTITION BY batch_id) AS first_load,
       ROW_NUMBER() OVER (PARTITION BY scan_id ORDER BY loaded_at_utc) AS rn
FROM parsed
WHERE scan_id IS NOT NULL)

SELECT scan_id, order_id, code, qty, weight_lb, batch_id, loaded_at_utc
FROM dedup
WHERE rn = 1
  AND COALESCE(loaded_at_utc, '') = COALESCE(first_load, '')

-- task: normalize_order
WITH normalized AS (
SELECT
    CASE
        WHEN lower(trim(event_id, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(event_id, ' ' || char(9) || char(10) || char(13))
    END AS event_id,

    CASE
        WHEN lower(trim(order_id, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(order_id, ' ' || char(9) || char(10) || char(13))
    END AS order_id,

    CASE
        WHEN lower(trim(event, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE lower(trim(event, ' ' || char(9) || char(10) || char(13)))
    END AS event_name,

    CASE
        WHEN lower(trim(event_at, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(event_at, ' ' || char(9) || char(10) || char(13))
    END AS event_at,

    CASE
        WHEN lower(trim(detail, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE lower(trim(detail, ' ' || char(9) || char(10) || char(13)))
    END AS detail,

    CASE
        WHEN lower(trim(written_at, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(written_at, ' ' || char(9) || char(10) || char(13))
    END AS written_at

FROM order_events),

canonicalized AS (
SELECT
    normalized.*,
    CASE
        WHEN event_name IN ('placed', 'order_placed', 'order placed', 'order-placed')
        THEN 'placed'
        WHEN event_name IN ('delivered', 'order_delivered', 'order delivered', 'order-delivered', 'delivery_completed', 'delivery completed', 'dropped_off', 'dropped off')
        THEN 'delivered'
        WHEN event_name IN ('cancelled', 'canceled', 'order_cancelled', 'order_canceled', 'order cancelled', 'order canceled')
        THEN 'cancelled'
        WHEN event_name IN ('reinstated', 'order_reinstated', 'order reinstated', 'uncancelled', 'uncanceled', 'cancellation_reversed')
        THEN 'reinstated'
        WHEN event_name IN ('deleted', 'order_deleted', 'order deleted', 'support_deleted', 'support deleted')
        THEN 'deleted'
        WHEN event_name IN ('tip_changed', 'tip changed', 'tip_updated', 'tip updated', 'gratuity_changed', 'gratuity_updated')
        THEN 'tip_changed'
        WHEN event_name IN ('replacement_declined', 'replacement declined', 'substitution_declined', 'substitution declined', 'replacement_rejected', 'substitution_rejected')
        THEN 'replacement_declined'
        WHEN event_name IN ('replacement_approved', 'replacement approved', 'substitution_approved', 'substitution approved', 'replacement_accepted', 'substitution_accepted')
        THEN 'replacement_approved'
        ELSE event_name
    END AS canonical_event
FROM normalized),

parsed AS (
SELECT
    CASE
        WHEN regexp_like(lower(event_id), '^[0-9a-f]{12}$')
        THEN lower('ev_' || event_id)
        WHEN regexp_like(lower(event_id), '^ev[_ /]*[0-9a-f]{12}$')
        THEN lower('ev_' || substr(event_id, length(event_id) - 11, 12))
        ELSE NULL
    END AS event_id,

    CASE
        WHEN regexp_like(order_id, '^[0-9]{1,8}$')
        THEN substr('00000000' || order_id, length('00000000' || order_id) - 7, 8)
        ELSE NULL
    END AS order_id,

    event_name,
    canonical_event,
    event_at,

    CASE
        WHEN event_at IS NULL
        THEN NULL
        WHEN regexp_like(event_at, '^[0-9]{16}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_at AS REAL) / 1000000.0, 'unixepoch')
        WHEN regexp_like(event_at, '^[0-9]{13}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_at AS REAL) / 1000.0, 'unixepoch')
        WHEN regexp_like(event_at, '^[0-9]{10}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_at AS REAL), 'unixepoch')
        WHEN regexp_like(event_at, '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(event_at, 1, length(event_at) - 3) || substr(event_at, length(event_at) - 2, 3) || ':00')
        ELSE strftime('%Y-%m-%dT%H:%M:%SZ', event_at)
    END AS event_at_utc,

    detail,

    CASE
        WHEN canonical_event IN ('placed', 'tip_changed') AND regexp_like(detail, '^[0-9]+([.][0-9]{1,2})?$')
        THEN CAST(detail AS DECIMAL(10, 2))
        ELSE NULL
    END AS detail_tip,

    CASE
        WHEN canonical_event IN ('replacement_declined', 'replacement_approved')
             AND regexp_like(lower(detail), '^[0-9a-f]{12}$')
        THEN lower('sc_' || detail)
        WHEN canonical_event IN ('replacement_declined', 'replacement_approved')
             AND regexp_like(lower(detail), '^sc[_ /]*[0-9a-f]{12}$')
        THEN lower('sc_' || substr(detail, length(detail) - 11, 12))
        ELSE NULL
    END AS replacement_scan_id,

    written_at,

    CASE
        WHEN written_at IS NULL
        THEN NULL
        WHEN regexp_like(written_at, '^[0-9]{16}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(written_at AS REAL) / 1000000.0, 'unixepoch')
        WHEN regexp_like(written_at, '^[0-9]{13}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(written_at AS REAL) / 1000.0, 'unixepoch')
        WHEN regexp_like(written_at, '^[0-9]{10}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(written_at AS REAL), 'unixepoch')
        WHEN regexp_like(written_at, '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}$')
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(written_at, 1, length(written_at) - 3) || substr(written_at, length(written_at) - 2, 3) || ':00')
        ELSE strftime('%Y-%m-%dT%H:%M:%SZ', written_at)
    END AS written_at_utc

FROM canonicalized),

filtered AS (
SELECT * FROM parsed
WHERE event_id IS NOT NULL),

dedup AS (
SELECT filtered.*,
       ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY written_at_utc DESC) AS rn
FROM filtered)

SELECT event_id, order_id, event_name, canonical_event,
       event_at, event_at_utc, detail, detail_tip,
       replacement_scan_id, written_at, written_at_utc
FROM dedup
WHERE rn = 1

-- task: normalize_price
WITH normalized AS (
SELECT
    CASE
        WHEN lower(trim(code, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(code, ' ' || char(9) || char(10) || char(13))
    END AS code,

    CASE
        WHEN lower(trim(price, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(price, ' ' || char(9) || char(10) || char(13))
    END AS price,

    CASE
        WHEN lower(trim(sold_by, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE lower(trim(sold_by, ' ' || char(9) || char(10) || char(13)))
    END AS sold_by,

    CASE
        WHEN lower(trim(_loaded_at, ' ' || char(9) || char(10) || char(13))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?', char(92) || 'n')
        THEN NULL
        ELSE trim(_loaded_at, ' ' || char(9) || char(10) || char(13))
    END AS _loaded_at

FROM prices),

parsed AS (
    SELECT
        code,

        CASE
            WHEN regexp_like(code, '^2[0-9]{10,}$')
            THEN 'store_label'
            WHEN regexp_like(code, '^[0-9]{12}$')
            THEN 'UPC'
            WHEN regexp_like(code, '^[0-9]{4,5}$')
            THEN 'PLU'
            ELSE 'unknown'
        END AS code_type,

        CASE
            WHEN regexp_like(price, '^[0-9]+([.][0-9]+)?$')
            THEN CAST(price AS DECIMAL(18, 6))
            ELSE NULL
        END AS price,

        CASE
            WHEN sold_by IN ('each', 'lb')
            THEN sold_by
            ELSE NULL
        END AS sold_by,

        _loaded_at,

        CASE
            WHEN _loaded_at IS NULL
            THEN NULL
            WHEN regexp_like(_loaded_at, '^[0-9]{16}$')
            THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(_loaded_at AS REAL) / 1000000.0, 'unixepoch')
            WHEN regexp_like(_loaded_at, '^[0-9]{13}$')
            THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(_loaded_at AS REAL) / 1000.0, 'unixepoch')
            WHEN regexp_like(_loaded_at, '^[0-9]{10}$')
            THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(_loaded_at AS REAL), 'unixepoch')
            WHEN regexp_like(_loaded_at, '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}$')
            THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(_loaded_at, 1, length(_loaded_at) - 3) || substr(_loaded_at, length(_loaded_at) - 2, 3) || ':00')
            ELSE strftime('%Y-%m-%dT%H:%M:%SZ', _loaded_at)
        END AS loaded_at_utc

    FROM normalized)

SELECT code, price, sold_by, loaded_at_utc
FROM parsed
WHERE code IS NOT NULL
  AND price IS NOT NULL
  AND loaded_at_utc IS NOT NULL

-- task: order_charges
WITH ev AS (
  SELECT order_id, event_name, event_time, detail_tip, replacement_scan_id, written_at
  FROM order_events_history
  WHERE order_id IS NOT NULL),

agg AS (
SELECT order_id,
     MIN(CASE WHEN event_name = 'placed'     THEN event_time END) AS placed_at,
     MIN(CASE WHEN event_name = 'delivered'  THEN event_time END) AS delivered_at,
     MAX(CASE WHEN event_name = 'cancelled'  THEN event_time END) AS cancelled_at,
     MAX(CASE WHEN event_name = 'reinstated' THEN event_time END) AS reinstated_at,
     MAX(CASE WHEN event_name = 'deleted'    THEN 1 ELSE 0 END)   AS is_deleted
FROM ev
GROUP BY order_id),

orders AS (
SELECT order_id, placed_at, delivered_at,
     CASE WHEN cancelled_at IS NOT NULL
            AND (reinstated_at IS NULL OR cancelled_at > reinstated_at)
          THEN 'cancelled' ELSE 'delivered' END AS status
FROM agg
WHERE is_deleted = 0
    AND placed_at >= '2026-10-16T00:00:00Z'
    AND placed_at <  '2026-11-15T00:00:00Z'),

tips AS (
SELECT order_id, detail_tip AS tip
FROM (
SELECT order_id, detail_tip,
       ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY event_time DESC, written_at DESC) AS rn
FROM ev
WHERE event_name IN ('placed', 'tip_changed') AND detail_tip IS NOT NULL)
WHERE rn = 1),

declined AS (
SELECT scan_id
FROM (
SELECT replacement_scan_id AS scan_id, event_name,
       ROW_NUMBER() OVER (PARTITION BY replacement_scan_id ORDER BY event_time DESC, written_at DESC) AS rn
FROM ev
WHERE replacement_scan_id IS NOT NULL
  AND event_name IN ('replacement_declined', 'replacement_approved'))
WHERE rn = 1 AND event_name = 'replacement_declined'),

-- price list collapsed to change points, then turned into validity intervals
p1 AS (
SELECT code, price, sold_by, loaded_at_utc,
     LAG(price)   OVER (PARTITION BY code ORDER BY loaded_at_utc) AS lp,
     LAG(sold_by) OVER (PARTITION BY code ORDER BY loaded_at_utc) AS ls
FROM prices_history),

p2 AS (
SELECT code, price, sold_by, loaded_at_utc, lp
FROM p1
WHERE lp IS NULL OR lp <> price OR COALESCE(ls, '') <> COALESCE(sold_by, '')),

pr AS (
SELECT code, price, sold_by,
     CASE WHEN lp IS NULL THEN '' ELSE loaded_at_utc END AS vfrom,
     LEAD(loaded_at_utc) OVER (PARTITION BY code ORDER BY loaded_at_utc) AS vto
FROM p2),

lines AS (
SELECT s.order_id,
     CASE
       WHEN substr(s.code, 1, 1) = '2' AND length(s.code) >= 11 THEN COALESCE(s.qty, 1)
       WHEN pr.sold_by = 'lb' THEN 1
       ELSE COALESCE(s.qty, 1)
     END AS items,
     CASE
       WHEN substr(s.code, 1, 1) = '2' AND length(s.code) >= 11
         THEN COALESCE(s.qty, 1) * CAST(substr(s.code, 7, 5) AS INTEGER)
       WHEN pr.sold_by = 'lb'
         THEN CAST(ROUND(COALESCE(s.weight_lb, s.qty, 0) * pr.price * 100 + 0.0000001) AS INTEGER)
       WHEN pr.price IS NOT NULL
         THEN COALESCE(s.qty, 1) * CAST(ROUND(pr.price * 100) AS INTEGER)
       ELSE 0
     END AS cents
FROM scans_history s
JOIN orders o ON o.order_id = s.order_id AND o.status = 'delivered'
LEFT JOIN declined d ON d.scan_id = s.scan_id
LEFT JOIN pr ON pr.code = s.code
          AND o.placed_at >  pr.vfrom
          AND (pr.vto IS NULL OR o.placed_at <= pr.vto)
WHERE d.scan_id IS NULL),

tot AS (
SELECT order_id, CAST(SUM(items) AS INTEGER) AS items, SUM(cents) AS cents
FROM lines
GROUP BY order_id)

SELECT o.order_id,
       o.status,
       CASE WHEN o.status = 'cancelled' THEN NULL ELSE o.delivered_at END AS delivered_at,
       CASE WHEN o.status = 'cancelled' THEN 0 ELSE COALESCE(t.items, 0) END AS items,
       CASE WHEN o.status = 'cancelled' THEN 0.0 ELSE ROUND(COALESCE(t.cents, 0) / 100.0, 2) END AS subtotal,
       CASE WHEN o.status = 'cancelled' THEN 0.0 ELSE ROUND(COALESCE(tp.tip, 0) * 1.0, 2) END AS tip
FROM orders o
LEFT JOIN tot  t  ON t.order_id  = o.order_id
LEFT JOIN tips tp ON tp.order_id = o.order_id
