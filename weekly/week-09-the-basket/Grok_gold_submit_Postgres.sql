/* dag.yml
dag: the_basket
schedule: "0 2,6,10,14,18,22 * * *"
tasks:
  events_hist:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [event_id]
    depends_on: [order_events]
  scans_hist:
    materialized: incremental
    incremental_strategy: insert_overwrite
    partition_by: [_batch_id, _loaded_at]
    depends_on: [scans]
    schedule: "0 6 * * *"
  prices_hist:
    materialized: incremental
    incremental_strategy: insert_overwrite
    partition_by: [_loaded_at]
    depends_on: [prices]
  order_charges:
    materialized: table
    depends_on: [events_hist, scans_hist, prices_hist]
    trigger_rule: none_failed
    schedule: "0 6 * * *"
*/
 
-- task: events_hist
SELECT DISTINCT * FROM order_events;
 
-- task: scans_hist
SELECT DISTINCT * FROM scans;
 
-- task: prices_hist
SELECT DISTINCT * FROM prices;
 
-- task: order_charges
WITH ev0 AS (
  SELECT DISTINCT event_id, order_id, event, event_at, detail, written_at FROM events_hist
),
ev1 AS (
  SELECT event_id,
    trim(order_id) AS o1,
    lower(regexp_replace(coalesce(event, ''), '[^A-Za-z]', '', 'g')) AS e,
    regexp_replace(regexp_replace(regexp_replace(replace(replace(trim(coalesce(event_at, '')), ' UTC', 'Z'), 'T', ' '),
      '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$', '\1\3:00'),
      '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})([0-9]{2})$', '\1\3:\4'),
      '^([0-9]{2})/([0-9]{2})/([0-9]{4})', '\3-\1-\2') AS s,
    regexp_replace(replace(trim(coalesce(written_at, '')), 'T', ' '), '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$', '\1\3:00') AS ws,
    trim(detail) AS detail
  FROM ev0
),
ev AS (
  SELECT event_id, e, detail,
    right('00000000' || regexp_replace(CASE WHEN position('.' in o1) > 0 THEN substring(o1 from 1 for position('.' in o1) - 1) ELSE o1 END, '[^0-9]', '', 'g'), 8) AS oid,
    CASE
      WHEN s <> '' AND regexp_replace(s, '[0-9]', '', 'g') = '' AND length(s) = 13 THEN to_timestamp(s::bigint / 1000.0)
      WHEN s <> '' AND regexp_replace(s, '[0-9]', '', 'g') = '' AND length(s) BETWEEN 9 AND 10 THEN to_timestamp(s::bigint)
      ELSE s::timestamp
    END AS ts,
    coalesce(ws::timestamp, ws) AS wts
  FROM ev1
),
evn AS (
  SELECT *,
    CASE
      WHEN e LIKE '%replac%' OR e LIKE '%substitut%' THEN
        CASE WHEN e LIKE '%declin%' OR e LIKE '%reject%' OR e LIKE '%deni%' OR e LIKE '%refus%' THEN 'rdec'
             WHEN e LIKE '%approv%' OR e LIKE '%accept%' OR e LIKE '%confirm%' THEN 'rapp' END
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
  SELECT *,
    row_number() OVER (PARTITION BY oid, CASE WHEN k IN ('cancelled', 'reinstated') THEN 'cr' WHEN k IN ('placed', 'tip') THEN 'tp' ELSE k END
                       ORDER BY ts DESC, wts DESC, event_id DESC) AS rn
  FROM evn
),
orders AS (
  SELECT oid,
    min(CASE WHEN k = 'placed' THEN ts END) AS placed_at,
    max(CASE WHEN k = 'deleted' THEN 1 ELSE 0 END) AS is_del,
    min(CASE WHEN k = 'delivered' THEN ts END) AS delivered_ts,
    max(CASE WHEN k IN ('cancelled', 'reinstated') AND rn = 1 THEN k END) AS last_cr,
    max(CASE WHEN k IN ('placed', 'tip') AND rn = 1 THEN detail END) AS tip_txt
  FROM ranked
  GROUP BY oid
),
ord AS (
  SELECT * FROM orders
  WHERE is_del = 0 AND placed_at >= '2026-10-16' AND placed_at < '2026-11-15'
),
repl AS (
  SELECT detail AS scan_id, k FROM (
    SELECT detail, k, row_number() OVER (PARTITION BY detail ORDER BY ts DESC, wts DESC, event_id DESC) AS rn
    FROM evn WHERE k IN ('rdec', 'rapp')
  ) WHERE rn = 1
),
sc1 AS (
  SELECT DISTINCT trim(scan_id) AS scan_id, order_id, code, qty, weight_lb,
    regexp_replace(coalesce(_batch_id, ''), '[^0-9]', '', 'g') AS bday,
    (regexp_replace(replace(trim(_loaded_at), 'T', ' '), '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$', '\1\3:00'))::timestamp AS lts
  FROM scans_hist
),
sc2 AS (
  SELECT * FROM (
    SELECT *, max(lts) OVER (PARTITION BY bday) AS mlts FROM sc1
  ) WHERE lts = mlts
),
sc AS (
  SELECT scan_id,
    right('00000000' || regexp_replace(CASE WHEN position('.' in trim(order_id)) > 0 THEN substring(trim(order_id) from 1 for position('.' in trim(order_id)) - 1) ELSE trim(order_id) END, '[^0-9]', '', 'g'), 8) AS oid,
    regexp_replace(coalesce(code, ''), '[^0-9]', '', 'g') AS code_raw,
    CASE WHEN regexp_replace(coalesce(qty, ''), '[^0-9]', '', 'g') <> '' THEN (regexp_replace(qty, '[^0-9.\-]', '', 'g'))::float8 END AS q,
    CASE WHEN regexp_replace(coalesce(weight_lb, ''), '[^0-9]', '', 'g') <> '' THEN (regexp_replace(weight_lb, '[^0-9.\-]', '', 'g'))::float8 END AS w
  FROM sc2
  WHERE scan_id NOT IN (SELECT scan_id FROM repl WHERE k = 'rdec')
),
scn AS (
  SELECT *,
    CASE WHEN length(code_raw) = 13 AND code_raw LIKE '0%' THEN substring(code_raw from 2) ELSE code_raw END AS code12,
    ltrim(code_raw, '0') AS ckey
  FROM sc
),
pr0 AS (
  SELECT DISTINCT ltrim(regexp_replace(coalesce(code, ''), '[^0-9]', '', 'g'), '0') AS ckey,
    (round((regexp_replace(price, '[^0-9.\-]', '', 'g'))::float8 * 100))::integer AS pc,
    CASE WHEN lower(coalesce(sold_by, '')) LIKE '%lb%' OR lower(coalesce(sold_by, '')) LIKE '%pound%' THEN 'lb' ELSE 'each' END AS sb,
    (regexp_replace(replace(trim(_loaded_at), 'T', ' '), '(:[0-9]{2}(\.[0-9]+)?) ?([+-][0-9]{2})$', '\1\3:00'))::timestamp AS lts
  FROM prices_hist
),
pr1 AS (
  SELECT *, lag(pc) OVER (PARTITION BY ckey ORDER BY lts) AS ppc, lag(sb) OVER (PARTITION BY ckey ORDER BY lts) AS psb,
    row_number() OVER (PARTITION BY ckey ORDER BY lts) AS first_rn
  FROM pr0
),
pr AS (
  SELECT ckey, pc, sb, lts FROM pr1
  WHERE first_rn = 1 OR ppc <> pc OR psb <> sb
),
items AS (
  SELECT s.oid, s.scan_id, s.code12, s.q, s.w, s.ckey, o.placed_at,
    row_number() OVER (PARTITION BY s.oid, s.scan_id, s.code12, s.q, s.w
                       ORDER BY CASE WHEN p.lts <= o.placed_at THEN 0 ELSE 1 END, CASE WHEN p.lts <= o.placed_at THEN p.lts END DESC, p.lts) AS prn,
    p.pc, p.sb
  FROM scn s JOIN ord o ON o.oid = s.oid
  LEFT JOIN pr p ON p.ckey = s.ckey
),
line AS (
  SELECT oid, q, w,
    CASE WHEN length(code12) = 12 AND code12 LIKE '2%' THEN 'label' ELSE sb END AS sb,
    CASE WHEN length(code12) = 12 AND code12 LIKE '2%' THEN (substring(code12 from 7 for 5))::integer ELSE pc END AS pc
  FROM items WHERE prn = 1
),
agg AS (
  SELECT oid,
    sum(CASE WHEN sb = 'lb' THEN CASE WHEN coalesce(w, q) < 0 THEN -1 WHEN coalesce(w, q) > 0 THEN 1 ELSE 0 END ELSE coalesce(q, 0) END) AS n,
    sum(CASE WHEN sb = 'lb' THEN (round(coalesce(w, q) * pc + 0.000001))::integer
             ELSE (round(coalesce(q, 0) * pc + 0.000001))::integer END) AS cents
  FROM line GROUP BY oid
)
SELECT o.oid AS order_id,
  CASE WHEN o.last_cr = 'cancelled' THEN 'cancelled' ELSE 'delivered' END AS status,
  CASE WHEN o.last_cr = 'cancelled' OR o.delivered_ts IS NULL THEN NULL
       ELSE to_char(o.delivered_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') END AS delivered_at,
  CASE WHEN o.last_cr = 'cancelled' THEN 0 ELSE (round(coalesce(a.n, 0)))::integer END AS items,
  CASE WHEN o.last_cr = 'cancelled' THEN 0.0 ELSE round(coalesce(a.cents, 0) / 100.0, 2) END AS subtotal,
  CASE WHEN o.last_cr = 'cancelled' THEN 0.0
       ELSE round(coalesce((regexp_replace(o.tip_txt, '[^0-9.\-]', '', 'g'))::float8, 0), 2) END AS tip
FROM ord o LEFT JOIN agg a ON a.oid = o.oid
