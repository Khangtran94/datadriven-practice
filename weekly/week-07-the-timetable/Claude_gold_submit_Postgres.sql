/* PostgreSQL port of gold_submit.sql (Week 7, The Timetable). File: Claude_gold_submit_Postgres.sql
   The original gold is SQLite SQL. This file gives the same DAG, the same task order and the same output columns in plain PostgreSQL.

   NEEDS: PostgreSQL 16 or newer (pg_input_is_valid() is new in 16).
   ASSUMPTIONS: every raw column of trip_updates and trips is TEXT (as the data doc says). The Jinja markers
   ({% if is_incremental() %}, {{ this }}, {{ ts }}) are kept exactly as in the gold.
   PLAIN SQL ONLY: no CREATE FUNCTION, no DO blocks, no extensions. Each task is one WITH ... SELECT built in steps with a comment per step.

   COPIED FROM THE GOLD ON PURPOSE (not fixed): the 07:00 UTC service-day start (agency clock is UTC-7), the 12-hour match window,
   the hard-coded service_date window 2026-10-02 .. 2026-10-31 (it matches the README), the choice of the newest export per key.
   The gold's CTE "tu_source" / "tt_source" (SELECT table.*, NULL AS col ...) only guards against missing columns; here the documented columns are read directly.
   KNOWN DIFFERENCES ON INPUT THE README DOES NOT SHOW: a bare number in _loaded_at or _batch_id (SQLite reads it as a julian day), and
   an impossible date such as 2026-02-30 inside julianday() (SQLite rolls it to 2026-03-02, here it is NULL), and
   half-way rounding of a fractional-day clock (SQLite uses binary floats, here numeric). Tested on README-shaped data only.

   SQLite -> PostgreSQL cheat sheet used below:
     trim(x, chars)         -> btrim(x, E' \t\n\r\u00a0')     (E'' so the escapes mean tab, line feed ...)
     x GLOB '*[^0-9]*'      -> x ~ '^[0-9]*$'  (NOT GLOB becomes the regex that allows digits only)
     instr(a, b)            -> strpos(a, b)
     substr(x, -1)          -> right(x, 1)
     date(x) / datetime(x)  -> regex shape + pg_input_is_valid(x, 'date' / 'timestamp') + cast, so a bad text gives NULL instead of an error
     julianday(x)           -> (milliseconds since 1970 + 210866760000000) / 86400000.0   (the same number SQLite returns)
     strftime('%s', x)      -> floor(extract(epoch from x))
     json_array(...)        -> '[' || to_json(a) || ',' || ... || ']'
     ORDER BY x DESC        -> ORDER BY x DESC NULLS LAST (SQLite puts NULL smallest; PostgreSQL puts NULL first on DESC); ASC needs NULLS FIRST
     text compare / max     -> COLLATE "C" (SQLite compares bytes)
*/

/* dag.yml
dag: the_timetable
schedule: 0 1,7,13,19 * * *
catchup: true
tasks:
  rail_ready:
    materialized: sensor
    depends_on:
    - trip_updates
    schedule: 0 13 * * *
    timeout: 12h
    soft_fail: true
  trip_updates_history:
    materialized: incremental
    depends_on:
    - trip_updates
    - rail_ready
    incremental_strategy: merge
    unique_key:
    - event_key
    trigger_rule: none_failed
  trips_history:
    materialized: incremental
    depends_on:
    - trips
    - rail_ready
    incremental_strategy: merge
    unique_key:
    - file_key
    - trip_id
    trigger_rule: none_failed
  timetable_versions:
    materialized: view
    depends_on:
    - trips_history
  timetable_entries:
    materialized: view
    depends_on:
    - timetable_versions
    - trips_history
  resolved_events:
    materialized: view
    depends_on:
    - trip_updates_history
    - timetable_entries
  trip_actuals:
    materialized: view
    depends_on:
    - resolved_events
*/

-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after


-- task: trip_updates_history
WITH b AS (
  -- b: trim spaces, tabs, line breaks and non-breaking spaces from every raw column (the raw _batch_id is kept for the incremental filter)
  SELECT btrim(update_id, E' \t\n\r\u00a0') AS update_id,
         btrim(trip_id, E' \t\n\r\u00a0') AS trip_id,
         btrim(start_date, E' \t\n\r\u00a0') AS start_date,
         btrim(route_id, E' \t\n\r\u00a0') AS route_id,
         btrim(vehicle_id, E' \t\n\r\u00a0') AS vehicle_id,
         btrim(event_type, E' \t\n\r\u00a0') AS event_type,
         btrim(schedule_relationship, E' \t\n\r\u00a0') AS schedule_relationship,
         btrim(event_time, E' \t\n\r\u00a0') AS event_time,
         btrim(feed, E' \t\n\r\u00a0') AS feed,
         btrim(_batch_id, E' \t\n\r\u00a0') AS _batch_id,
         btrim(_loaded_at, E' \t\n\r\u00a0') AS _loaded_at,
         _batch_id AS raw_batch
  FROM trip_updates
), c AS (
  -- c: a null marker written as text (NULL, \N, n/a, ...) becomes a real NULL
  SELECT CASE WHEN lower(update_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE update_id END AS update_id,
         CASE WHEN lower(trip_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trip_id END AS trip_id,
         CASE WHEN lower(start_date) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE start_date END AS start_date,
         CASE WHEN lower(route_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE route_id END AS route_id,
         CASE WHEN lower(vehicle_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE vehicle_id END AS vehicle_id,
         CASE WHEN lower(event_type) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE event_type END AS event_type,
         CASE WHEN lower(schedule_relationship) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE schedule_relationship END AS schedule_relationship,
         CASE WHEN lower(event_time) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE event_time END AS event_time,
         CASE WHEN lower(feed) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE feed END AS feed,
         CASE WHEN lower(_batch_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE _batch_id END AS _batch_id,
         CASE WHEN lower(_loaded_at) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE _loaded_at END AS _loaded_at,
         raw_batch
  FROM b
), p AS (
  -- p: _loaded_at in one shape (Z, +hh and +hhmm become +hh:mm)
  SELECT c.*, CASE WHEN right(c._loaded_at,1) IN ('Z','z') THEN left(c._loaded_at, length(c._loaded_at) - 1) || 'Z'
         WHEN length(c._loaded_at) > 10 AND c._loaded_at ~ '[+-][0-9]{2}$' THEN c._loaded_at || ':00'
         WHEN length(c._loaded_at) > 10 AND c._loaded_at ~ '[+-][0-9]{4}$' THEN left(c._loaded_at, length(c._loaded_at) - 2) || ':' || right(c._loaded_at, 2)
         ELSE c._loaded_at END AS la_norm FROM c
), q AS (
  -- q: _loaded_at as a julian day number, the value SQLite's julianday() gives; NULL when it does not parse
  SELECT p.*, CASE WHEN p.la_norm ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}(:[0-9]{2}([.][0-9]+)?)?(Z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(p.la_norm, 'timestamptz') THEN (round(extract(epoch from (p.la_norm)::timestamptz) * 1000)::bigint + 210866760000000) / 86400000.0::float8
         WHEN p.la_norm ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}([ T][0-9]{2}:[0-9]{2}(:[0-9]{2}([.][0-9]+)?)?)?$' AND pg_input_is_valid(p.la_norm, 'timestamp') THEN (round(extract(epoch from (p.la_norm)::timestamp) * 1000)::bigint + 210866760000000) / 86400000.0::float8 END AS la_ord FROM p
), f AS (
  -- f: an incremental run reads only rows at least as new as the newest row already loaded; the 13:00 run reads everything
  SELECT * FROM q
  {% if is_incremental() %}
  WHERE to_char(CAST('{{ ts }}' AS timestamp), 'HH24') = '13'
     OR coalesce(la_ord, CASE WHEN substr(raw_batch,1,10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(substr(raw_batch,1,10), 'date')
                          THEN (((substr(raw_batch,1,10)::date - date '1970-01-01')::bigint * 86400000) + 210866760000000) / 86400000.0::float8 END)
        >= coalesce((SELECT max(loaded_ord) FROM {{ this }}), 0) - 0.000001
  {% endif %}
), t AS (
  -- t: take spreadsheet leftovers (="123", '123, 123.0) off the ids and map the event words
  SELECT CASE WHEN left(update_id,2) = '="' AND right(update_id,1) = '"' AND length(update_id) >= 3 THEN substr(update_id, 3, length(update_id) - 3)
         WHEN left(update_id,1) = chr(39) THEN substr(update_id, 2)
         WHEN strpos(update_id,'.') > 1 AND substr(update_id, 1, greatest(strpos(update_id,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(update_id, strpos(update_id,'.') + 1)) > 0 AND substr(update_id, strpos(update_id,'.') + 1) ~ '^0*$'
         THEN substr(update_id, 1, strpos(update_id,'.') - 1)
         ELSE update_id END AS update_id,
         CASE WHEN left(trip_id,2) = '="' AND right(trip_id,1) = '"' AND length(trip_id) >= 3 THEN substr(trip_id, 3, length(trip_id) - 3)
         WHEN left(trip_id,1) = chr(39) THEN substr(trip_id, 2)
         WHEN strpos(trip_id,'.') > 1 AND substr(trip_id, 1, greatest(strpos(trip_id,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(trip_id, strpos(trip_id,'.') + 1)) > 0 AND substr(trip_id, strpos(trip_id,'.') + 1) ~ '^0*$'
         THEN substr(trip_id, 1, strpos(trip_id,'.') - 1)
         ELSE trip_id END AS trip_id,
         CASE WHEN left(start_date,2) = '="' AND right(start_date,1) = '"' AND length(start_date) >= 3 THEN substr(start_date, 3, length(start_date) - 3)
         WHEN left(start_date,1) = chr(39) THEN substr(start_date, 2)
         WHEN strpos(start_date,'.') > 1 AND substr(start_date, 1, greatest(strpos(start_date,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(start_date, strpos(start_date,'.') + 1)) > 0 AND substr(start_date, strpos(start_date,'.') + 1) ~ '^0*$'
         THEN substr(start_date, 1, strpos(start_date,'.') - 1)
         ELSE start_date END AS start_text,
         CASE WHEN left(route_id,2) = '="' AND right(route_id,1) = '"' AND length(route_id) >= 3 THEN substr(route_id, 3, length(route_id) - 3)
         WHEN left(route_id,1) = chr(39) THEN substr(route_id, 2)
         WHEN strpos(route_id,'.') > 1 AND substr(route_id, 1, greatest(strpos(route_id,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(route_id, strpos(route_id,'.') + 1)) > 0 AND substr(route_id, strpos(route_id,'.') + 1) ~ '^0*$'
         THEN substr(route_id, 1, strpos(route_id,'.') - 1)
         ELSE route_id END AS route_id,
         CASE WHEN left(vehicle_id,2) = '="' AND right(vehicle_id,1) = '"' AND length(vehicle_id) >= 3 THEN substr(vehicle_id, 3, length(vehicle_id) - 3)
         WHEN left(vehicle_id,1) = chr(39) THEN substr(vehicle_id, 2)
         WHEN strpos(vehicle_id,'.') > 1 AND substr(vehicle_id, 1, greatest(strpos(vehicle_id,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(vehicle_id, strpos(vehicle_id,'.') + 1)) > 0 AND substr(vehicle_id, strpos(vehicle_id,'.') + 1) ~ '^0*$'
         THEN substr(vehicle_id, 1, strpos(vehicle_id,'.') - 1)
         ELSE vehicle_id END AS vehicle_text,
         CASE WHEN lower(event_type) IN ('start','started','depart','departure','departed','departed_origin','trip_start','trip started','trip_started','begin','began') THEN 'start'
              WHEN lower(event_type) IN ('end','ended','finish','finished','complete','completed','arrival','arrive','arrived','trip_end','trip_completed','stop') THEN 'end'
              WHEN lower(event_type) IN ('cancel','canceled','cancelled','cancellation','cancelled_trip','trip_cancelled','trip_canceled','cancel_trip') THEN 'cancel'
              WHEN upper(schedule_relationship) IN ('CANCELED','CANCELLED') THEN 'cancel' END AS event_kind,
         upper(schedule_relationship) AS relationship,
         lower(feed) AS feed,
         event_time,
         _batch_id,
         la_ord
  FROM f
), d AS (
  -- d: numbers and days read out of the text columns
  SELECT t.*,
         CASE WHEN event_time ~ '^[+-]?[0-9]+$' THEN event_time::numeric
         WHEN regexp_replace(event_time, '^[+]', '') ~ '^-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?$' THEN event_time::numeric END AS event_number,
         CASE WHEN (CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid((CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END), 'date') THEN (CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END) END AS batch_day,
         CASE WHEN (CASE WHEN length(start_text) = 8 AND start_text ~ '^[0-9]*$' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2)
              ELSE substr(start_text,1,10) END) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid((CASE WHEN length(start_text) = 8 AND start_text ~ '^[0-9]*$' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2)
              ELSE substr(start_text,1,10) END), 'date') THEN (CASE WHEN length(start_text) = 8 AND start_text ~ '^[0-9]*$' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2)
              ELSE substr(start_text,1,10) END) END AS start_day_text,
         CASE WHEN start_text ~ '^[+-]?[0-9]+$' THEN start_text::numeric
         WHEN regexp_replace(start_text, '^[+]', '') ~ '^-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?$' THEN start_text::numeric END AS start_number,
         coalesce(la_ord, CASE WHEN substr(_batch_id,1,10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(substr(_batch_id,1,10), 'date')
         THEN (((substr(_batch_id,1,10)::date - date '1970-01-01')::bigint * 86400000) + 210866760000000) / 86400000.0::float8 END) AS loaded_ord,
         CASE WHEN right(event_time,1) IN ('Z','z') THEN left(event_time, length(event_time) - 1) || 'Z'
         WHEN length(event_time) > 10 AND event_time ~ '[+-][0-9]{2}$' THEN event_time || ':00'
         WHEN length(event_time) > 10 AND event_time ~ '[+-][0-9]{4}$' THEN left(event_time, length(event_time) - 2) || ':' || right(event_time, 2)
         ELSE event_time END AS event_iso
  FROM t
), e AS (
  -- e: does the event time carry its own offset (Z, +hh:mm, +hhmm, +hh)?
  SELECT d.*,
         (length(event_time) > 10 AND (right(event_time,1) IN ('Z','z')
              OR substr(event_time, length(event_time) - 5, 1) IN ('+','-')
              OR substr(event_time, length(event_time) - 4, 1) IN ('+','-')
              OR substr(event_time, length(event_time) - 2, 1) IN ('+','-'))) AS event_has_zone
  FROM d
), n AS (
  -- n: fleet number, declared service day, and the event time in epoch seconds
  SELECT update_id, trip_id,
         coalesce(start_day_text, CASE WHEN start_number BETWEEN 30000 AND 80000 THEN to_char(date '1899-12-30' + trunc(start_number)::int, 'YYYY-MM-DD') END) AS declared_day,
         route_id,
         CASE WHEN length(vehicle_text) > 0 AND vehicle_text ~ '^[0-9]*$' THEN vehicle_text
              WHEN lower(vehicle_text) ~ '^bus[- :_]' OR lower(vehicle_text) ~ '^rail[- :_]'
              THEN CASE WHEN length(ltrim(vehicle_text, 'bBuUsSrRaAiIlL -:_')) > 0
                         AND ltrim(vehicle_text, 'bBuUsSrRaAiIlL -:_') ~ '^[0-9]*$'
                        THEN ltrim(vehicle_text, 'bBuUsSrRaAiIlL -:_') END END AS vehicle_id,
         event_kind, relationship, feed,
         CASE WHEN abs(event_number) < 100000000000 THEN trunc(event_number)::bigint
              WHEN abs(event_number) < 100000000000000 THEN trunc(event_number / 1000)::bigint
              WHEN abs(event_number) < 100000000000000000 THEN trunc(event_number / 1000000)::bigint
              WHEN abs(event_number) < 100000000000000000000 THEN trunc(event_number / 1000000000)::bigint
              WHEN length(event_time) > 10 AND substr(event_time,1,10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(substr(event_time,1,10), 'date')
              THEN CASE WHEN event_has_zone
                        THEN CASE WHEN event_iso ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}(:[0-9]{2}([.][0-9]+)?)?(Z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(event_iso, 'timestamptz')
                                  THEN floor(extract(epoch from event_iso::timestamptz))::bigint END
                        ELSE CASE WHEN event_iso ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}([ T][0-9]{2}:[0-9]{2}(:[0-9]{2}([.][0-9]+)?)?)?$' AND pg_input_is_valid(event_iso, 'timestamp')
                                  THEN floor(extract(epoch from event_iso::timestamp))::bigint + 7 * 3600 END END
              END AS event_s,
         batch_day, loaded_ord
  FROM e WHERE trip_id IS NOT NULL
), incoming AS (
  -- incoming: one key per report: the ingest's id, or a key built from the fields when there is no id
  SELECT coalesce(update_id, '@' || '[' || coalesce(to_json(trip_id)::text, 'null') || ',' || coalesce(to_json(declared_day)::text, 'null') || ',' || coalesce(to_json(event_kind)::text, 'null') || ',' || coalesce(event_s::text, 'null') || ',' || coalesce(to_json(vehicle_id)::text, 'null') || ',' || coalesce(to_json(feed)::text, 'null') || ',' || coalesce(to_json(batch_day)::text, 'null') || ']') AS event_key,
         trip_id, declared_day, route_id, vehicle_id, event_kind, relationship, feed, event_s, batch_day, loaded_ord
  FROM n
), candidates AS (
  SELECT * FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.* FROM {{ this }} AS h
  JOIN (SELECT DISTINCT event_key FROM incoming) AS i ON i.event_key = h.event_key
  {% endif %}
), ranked AS (
  -- ranked: per key keep the newest export, then the row with the most facts
  SELECT *, row_number() OVER (PARTITION BY event_key
           ORDER BY loaded_ord DESC NULLS LAST, (event_s IS NOT NULL) DESC, (vehicle_id IS NOT NULL) DESC, (route_id IS NOT NULL) DESC) AS rn
  FROM candidates
)
SELECT event_key, trip_id, declared_day, route_id, vehicle_id, event_kind, relationship, feed, event_s, batch_day, loaded_ord
FROM ranked WHERE rn = 1;

-- task: trips_history
WITH b AS (
  -- b: trim spaces, tabs, line breaks and non-breaking spaces from every raw column (the raw _batch_id is kept for the incremental filter)
  SELECT btrim(trip_id, E' \t\n\r\u00a0') AS trip_id,
         btrim(route_id, E' \t\n\r\u00a0') AS route_id,
         btrim(service_id, E' \t\n\r\u00a0') AS service_id,
         btrim(direction_id, E' \t\n\r\u00a0') AS direction_id,
         btrim(trip_headsign, E' \t\n\r\u00a0') AS trip_headsign,
         btrim(first_departure, E' \t\n\r\u00a0') AS first_departure,
         btrim(feed_version, E' \t\n\r\u00a0') AS feed_version,
         btrim(feed_start_date, E' \t\n\r\u00a0') AS feed_start_date,
         btrim(_batch_id, E' \t\n\r\u00a0') AS _batch_id,
         btrim(_loaded_at, E' \t\n\r\u00a0') AS _loaded_at,
         _batch_id AS raw_batch
  FROM trips
), c AS (
  -- c: a null marker written as text (NULL, \N, n/a, ...) becomes a real NULL
  SELECT CASE WHEN lower(trip_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trip_id END AS trip_id,
         CASE WHEN lower(route_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE route_id END AS route_id,
         CASE WHEN lower(service_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE service_id END AS service_id,
         CASE WHEN lower(direction_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE direction_id END AS direction_id,
         CASE WHEN lower(trip_headsign) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trip_headsign END AS trip_headsign,
         CASE WHEN lower(first_departure) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE first_departure END AS first_departure,
         CASE WHEN lower(feed_version) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE feed_version END AS feed_version,
         CASE WHEN lower(feed_start_date) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE feed_start_date END AS feed_start_date,
         CASE WHEN lower(_batch_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE _batch_id END AS _batch_id,
         CASE WHEN lower(_loaded_at) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE _loaded_at END AS _loaded_at,
         raw_batch
  FROM b
), p AS (
  -- p: _loaded_at in one shape (Z, +hh and +hhmm become +hh:mm)
  SELECT c.*, CASE WHEN right(c._loaded_at,1) IN ('Z','z') THEN left(c._loaded_at, length(c._loaded_at) - 1) || 'Z'
         WHEN length(c._loaded_at) > 10 AND c._loaded_at ~ '[+-][0-9]{2}$' THEN c._loaded_at || ':00'
         WHEN length(c._loaded_at) > 10 AND c._loaded_at ~ '[+-][0-9]{4}$' THEN left(c._loaded_at, length(c._loaded_at) - 2) || ':' || right(c._loaded_at, 2)
         ELSE c._loaded_at END AS la_norm FROM c
), q AS (
  -- q: _loaded_at as a julian day number, the value SQLite's julianday() gives; NULL when it does not parse
  SELECT p.*, CASE WHEN p.la_norm ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}(:[0-9]{2}([.][0-9]+)?)?(Z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(p.la_norm, 'timestamptz') THEN (round(extract(epoch from (p.la_norm)::timestamptz) * 1000)::bigint + 210866760000000) / 86400000.0::float8
         WHEN p.la_norm ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}([ T][0-9]{2}:[0-9]{2}(:[0-9]{2}([.][0-9]+)?)?)?$' AND pg_input_is_valid(p.la_norm, 'timestamp') THEN (round(extract(epoch from (p.la_norm)::timestamp) * 1000)::bigint + 210866760000000) / 86400000.0::float8 END AS la_ord FROM p
), f AS (
  -- f: an incremental run reads only rows at least as new as the newest row already loaded; the 13:00 run reads everything
  SELECT * FROM q
  {% if is_incremental() %}
  WHERE to_char(CAST('{{ ts }}' AS timestamp), 'HH24') = '13'
     OR coalesce(la_ord, CASE WHEN substr(raw_batch,1,10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(substr(raw_batch,1,10), 'date')
                          THEN (((substr(raw_batch,1,10)::date - date '1970-01-01')::bigint * 86400000) + 210866760000000) / 86400000.0::float8 END)
        >= coalesce((SELECT max(loaded_ord) FROM {{ this }}), 0) - 0.000001
  {% endif %}
), t AS (
  -- t: take spreadsheet leftovers off the ids, the departure and the start date; map the service names
  SELECT CASE WHEN left(trip_id,2) = '="' AND right(trip_id,1) = '"' AND length(trip_id) >= 3 THEN substr(trip_id, 3, length(trip_id) - 3)
         WHEN left(trip_id,1) = chr(39) THEN substr(trip_id, 2)
         WHEN strpos(trip_id,'.') > 1 AND substr(trip_id, 1, greatest(strpos(trip_id,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(trip_id, strpos(trip_id,'.') + 1)) > 0 AND substr(trip_id, strpos(trip_id,'.') + 1) ~ '^0*$'
         THEN substr(trip_id, 1, strpos(trip_id,'.') - 1)
         ELSE trip_id END AS trip_id,
         CASE WHEN left(route_id,2) = '="' AND right(route_id,1) = '"' AND length(route_id) >= 3 THEN substr(route_id, 3, length(route_id) - 3)
         WHEN left(route_id,1) = chr(39) THEN substr(route_id, 2)
         WHEN strpos(route_id,'.') > 1 AND substr(route_id, 1, greatest(strpos(route_id,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(route_id, strpos(route_id,'.') + 1)) > 0 AND substr(route_id, strpos(route_id,'.') + 1) ~ '^0*$'
         THEN substr(route_id, 1, strpos(route_id,'.') - 1)
         ELSE route_id END AS route_id,
         CASE WHEN upper(service_id) IN ('WKD','WEEKDAY','WEEKDAYS') THEN 'WKD'
              WHEN upper(service_id) IN ('SAT','SATURDAY') THEN 'SAT'
              WHEN upper(service_id) IN ('SUN','SUNDAY') THEN 'SUN' ELSE upper(service_id) END AS service_id,
         CASE WHEN left(first_departure,2) = '="' AND right(first_departure,1) = '"' AND length(first_departure) >= 3 THEN substr(first_departure, 3, length(first_departure) - 3)
         WHEN left(first_departure,1) = chr(39) THEN substr(first_departure, 2)
         WHEN strpos(first_departure,'.') > 1 AND substr(first_departure, 1, greatest(strpos(first_departure,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(first_departure, strpos(first_departure,'.') + 1)) > 0 AND substr(first_departure, strpos(first_departure,'.') + 1) ~ '^0*$'
         THEN substr(first_departure, 1, strpos(first_departure,'.') - 1)
         ELSE first_departure END AS departure_text,
         CASE WHEN left(feed_start_date,2) = '="' AND right(feed_start_date,1) = '"' AND length(feed_start_date) >= 3 THEN substr(feed_start_date, 3, length(feed_start_date) - 3)
         WHEN left(feed_start_date,1) = chr(39) THEN substr(feed_start_date, 2)
         WHEN strpos(feed_start_date,'.') > 1 AND substr(feed_start_date, 1, greatest(strpos(feed_start_date,'.') - 1, 0)) ~ '^[0-9]*$'
          AND length(substr(feed_start_date, strpos(feed_start_date,'.') + 1)) > 0 AND substr(feed_start_date, strpos(feed_start_date,'.') + 1) ~ '^0*$'
         THEN substr(feed_start_date, 1, strpos(feed_start_date,'.') - 1)
         ELSE feed_start_date END AS start_text,
         feed_version, _batch_id, la_ord
  FROM f
), d AS (
  -- d: batch day, start day and release time
  SELECT t.*,
         CASE WHEN (CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid((CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END), 'date') THEN (CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END) END AS batch_day,
         CASE WHEN (CASE WHEN length(start_text) = 8 AND start_text ~ '^[0-9]*$' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2)
              ELSE substr(start_text,1,10) END) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid((CASE WHEN length(start_text) = 8 AND start_text ~ '^[0-9]*$' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2)
              ELSE substr(start_text,1,10) END), 'date') THEN (CASE WHEN length(start_text) = 8 AND start_text ~ '^[0-9]*$' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2)
              ELSE substr(start_text,1,10) END) END AS start_day_text,
         CASE WHEN start_text ~ '^[+-]?[0-9]+$' THEN start_text::numeric
         WHEN regexp_replace(start_text, '^[+]', '') ~ '^-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?$' THEN start_text::numeric END AS start_number,
         coalesce(la_ord, CASE WHEN substr(_batch_id,1,10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(substr(_batch_id,1,10), 'date')
         THEN (((substr(_batch_id,1,10)::date - date '1970-01-01')::bigint * 86400000) + 210866760000000) / 86400000.0::float8 END) AS loaded_ord,
         CASE WHEN departure_text ~ '^[+-]?[0-9]+$' THEN departure_text::numeric
         WHEN regexp_replace(departure_text, '^[+]', '') ~ '^-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+-]?[0-9]+)?$' THEN departure_text::numeric END AS excel_clock,
         lower(replace(departure_text, ' ', '')) AS clock_text
  FROM t WHERE trip_id IS NOT NULL
), clocks AS (
  -- clocks: the day the version starts to apply (an unreadable start date falls back to the day it was published)
  SELECT d.*,
         coalesce(coalesce(start_day_text, CASE WHEN start_number BETWEEN 30000 AND 80000 THEN to_char(date '1899-12-30' + trunc(start_number)::int, 'YYYY-MM-DD') END), batch_day) AS effective_day,
         CASE WHEN right(clock_text,2) IN ('am','pm') THEN left(clock_text, length(clock_text) - 2) ELSE clock_text END AS hms,
         CASE WHEN right(clock_text,2) IN ('am','pm') THEN right(clock_text,2) END AS ampm
  FROM d
), pieces AS (
  -- pieces: split H:MM:SS into hours, minutes and seconds (seconds default to 00)
  SELECT clocks.*,
         CASE WHEN strpos(hms, ':') > 0 THEN substr(hms, 1, strpos(hms, ':') - 1) END AS hh,
         CASE WHEN strpos(hms, ':') > 0 THEN
              CASE WHEN strpos(substr(hms, strpos(hms, ':') + 1), ':') > 0
                   THEN substr(hms, strpos(hms, ':') + 1, strpos(substr(hms, strpos(hms, ':') + 1), ':') - 1)
                   ELSE substr(hms, strpos(hms, ':') + 1) END END AS mm,
         CASE WHEN strpos(hms, ':') > 0 THEN
              CASE WHEN strpos(substr(hms, strpos(hms, ':') + 1), ':') > 0
                   THEN substr(hms, strpos(hms, ':') + 1 + strpos(substr(hms, strpos(hms, ':') + 1), ':'))
                   ELSE '00' END END AS ss
  FROM clocks
), shaped AS (
  -- shaped: does the clock text have a usable H:MM:SS shape (hours may pass 24)?
  SELECT pieces.*,
         (strpos(hms, ':') > 0 AND length(hh) BETWEEN 1 AND 3 AND length(mm) BETWEEN 1 AND 2 AND length(ss) BETWEEN 1 AND 2
          AND hh ~ '^[0-9]*$' AND mm ~ '^[0-9]*$' AND ss ~ '^[0-9]*$') AS shape_ok
  FROM pieces
), incoming AS (
  -- incoming: one row per trip per file, departure in seconds after the service day's 00:00
  SELECT '[' || coalesce(to_json(feed_version)::text, 'null') || ',' || coalesce(to_json(effective_day)::text, 'null') || ',' || coalesce(to_json(batch_day)::text, 'null') || ',' || (CASE WHEN loaded_ord IS NULL THEN 'null' WHEN position('.' in trim_scale(loaded_ord::numeric)::text) = 0 THEN trim_scale(loaded_ord::numeric)::text || '.0' ELSE trim_scale(loaded_ord::numeric)::text END) || ']' AS file_key, trip_id,
         route_id, service_id, effective_day, feed_version, batch_day, loaded_ord,
         CASE WHEN excel_clock >= 0 AND excel_clock < 7 THEN round(excel_clock * 86400, 0)::bigint
              WHEN shape_ok THEN
                CASE WHEN hh::int >= 0 AND mm::int < 60 AND ss::int < 60 AND (ampm IS NULL OR hh::int BETWEEN 1 AND 12)
                     THEN (CASE WHEN ampm IS NOT NULL THEN hh::int % 12 + CASE WHEN ampm = 'pm' THEN 12 ELSE 0 END ELSE hh::int END) * 3600 + mm::int * 60 + ss::int END
         END AS departure_s
  FROM shaped WHERE effective_day IS NOT NULL
), candidates AS (
  SELECT * FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.* FROM {{ this }} AS h
  JOIN (SELECT DISTINCT file_key, trip_id FROM incoming) AS i ON i.file_key = h.file_key AND i.trip_id = h.trip_id
  {% endif %}
), ranked AS (
  SELECT *, row_number() OVER (PARTITION BY file_key, trip_id
           ORDER BY (departure_s IS NOT NULL) DESC, (route_id IS NOT NULL) DESC) AS rn
  FROM candidates
)
SELECT file_key, trip_id, route_id, service_id, effective_day, feed_version, batch_day, loaded_ord, departure_s
FROM ranked WHERE rn = 1;

-- task: rail_ready
WITH b AS (
  -- b: trim the two columns the sensor reads
  SELECT btrim(feed, E' \t\n\r\u00a0') AS feed, btrim(_batch_id, E' \t\n\r\u00a0') AS _batch_id FROM trip_updates
), c AS (
  -- c: null markers written as text become NULL
  SELECT CASE WHEN lower(feed) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE feed END AS feed,
         CASE WHEN lower(_batch_id) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE _batch_id END AS _batch_id
  FROM b
)
-- ready when a rail row exists for yesterday's file
SELECT 1 WHERE EXISTS (
  SELECT 1 FROM c
  WHERE lower(feed) IN ('rail','light_rail','light rail','lrt','tram')
    AND CASE WHEN (CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid((CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END), 'date') THEN (CASE WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]*$' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2)
              ELSE substr(_batch_id,1,10) END) END = to_char(CAST('{{ ts }}' AS timestamp)::date - 1, 'YYYY-MM-DD')
);

-- task: timetable_versions
WITH files AS (
  -- files: one row per timetable file
  SELECT file_key, effective_day, max(loaded_ord) AS loaded_ord, max(batch_day COLLATE "C") AS batch_day,
         max(feed_version COLLATE "C") AS feed_version
  FROM trips_history GROUP BY file_key, effective_day
), ranked AS (
  -- ranked: for each start day the newest publication wins (an amended file sent again beats the first one)
  SELECT *, row_number() OVER (PARTITION BY effective_day
           ORDER BY loaded_ord DESC NULLS LAST, batch_day COLLATE "C" DESC NULLS LAST, feed_version COLLATE "C" DESC NULLS LAST, file_key COLLATE "C" DESC) AS rn
  FROM files
)
SELECT file_key, effective_day,
       lead(effective_day, 1, '9999-12-31') OVER (ORDER BY effective_day COLLATE "C") AS next_day
FROM ranked WHERE rn = 1;

-- task: timetable_entries
SELECT h.trip_id, h.route_id, h.service_id, h.departure_s, v.effective_day, v.next_day
FROM timetable_versions AS v JOIN trips_history AS h ON h.file_key = v.file_key;

-- task: resolved_events
WITH source AS (
  -- source: add the agency's calendar day of each event (UTC minus 7 hours)
  SELECT h.*, CASE WHEN event_s IS NOT NULL THEN to_char(to_timestamp(event_s) AT TIME ZONE 'UTC' - interval '7 hours', 'YYYY-MM-DD') END AS local_day
  FROM trip_updates_history AS h
), candidates AS (
  -- candidates: the declared day, or (no declared day) the event's calendar day and the 1 and 2 days before it
  SELECT s.*, coalesce(declared_day, local_day, batch_day) AS candidate_day FROM source AS s
  UNION ALL
  SELECT s.*, to_char(local_day::date - 1, 'YYYY-MM-DD') AS candidate_day FROM source AS s WHERE declared_day IS NULL AND local_day IS NOT NULL
  UNION ALL
  SELECT s.*, to_char(local_day::date - 2, 'YYYY-MM-DD') AS candidate_day FROM source AS s WHERE declared_day IS NULL AND local_day IS NOT NULL
), matched AS (
  -- matched: match each candidate day to the timetable version in force and to the days the trip runs;
  -- keep the candidate whose scheduled departure is nearest the event (within 12 hours)
  SELECT c.*, t.route_id AS scheduled_route, t.departure_s, t.trip_id AS scheduled_id,
         extract(epoch from (c.candidate_day::date + time '07:00'))::bigint + t.departure_s AS scheduled_s,
         row_number() OVER (PARTITION BY c.event_key
           ORDER BY (t.trip_id IS NOT NULL) DESC,
                    CASE WHEN c.declared_day IS NOT NULL THEN 0
                         ELSE abs(c.event_s - (extract(epoch from (c.candidate_day::date + time '07:00'))::bigint + t.departure_s)) END NULLS FIRST,
                    c.candidate_day COLLATE "C" DESC NULLS LAST) AS rn
  FROM candidates AS c
  LEFT JOIN timetable_entries AS t ON t.trip_id = c.trip_id
    AND c.candidate_day COLLATE "C" >= t.effective_day AND c.candidate_day COLLATE "C" < t.next_day
    AND (t.service_id IS NULL OR t.service_id NOT IN ('WKD','SAT','SUN')
         OR (t.service_id = 'WKD' AND extract(dow from c.candidate_day::date) BETWEEN 1 AND 5)
         OR (t.service_id = 'SAT' AND extract(dow from c.candidate_day::date) = 6)
         OR (t.service_id = 'SUN' AND extract(dow from c.candidate_day::date) = 0))
    AND (c.declared_day IS NOT NULL
         OR abs(c.event_s - (extract(epoch from (c.candidate_day::date + time '07:00'))::bigint + t.departure_s)) <= 43200)
), anchored AS (
  -- anchored: for a trip the timetable does not list, its first real start (on or after 07:00 UTC of its day) fixes its service day
  SELECT m.*,
         min(CASE WHEN event_kind = 'start'
                   AND (declared_day IS NULL OR event_s >= extract(epoch from (declared_day::date + time '07:00'))::bigint)
                  THEN event_s END)
           OVER (PARTITION BY trip_id, coalesce(declared_day, candidate_day), scheduled_id IS NULL) AS extra_start
  FROM matched AS m WHERE rn = 1
)
SELECT event_key, trip_id,
       CASE WHEN scheduled_id IS NOT NULL THEN candidate_day
            ELSE coalesce(CASE WHEN extra_start IS NOT NULL THEN to_char(to_timestamp(extra_start) AT TIME ZONE 'UTC' - interval '7 hours', 'YYYY-MM-DD') END,
                          declared_day, local_day, batch_day) END AS service_date,
       CASE WHEN scheduled_id IS NOT NULL THEN scheduled_route ELSE route_id END AS route_id,
       scheduled_s, event_s, event_kind, vehicle_id, loaded_ord,
       CASE WHEN scheduled_id IS NULL THEN 1 ELSE 0 END AS unscheduled
FROM anchored;

-- task: trip_actuals
WITH events AS (
  -- events: the planners' window
  SELECT *,
         coalesce(round(((loaded_ord - 2440587.5) * 86400000)::numeric)::bigint, 0) AS load_ms,
         coalesce(round(((loaded_ord - 2440587.5) * 86400)::numeric)::bigint, 0) AS load_s
  FROM resolved_events WHERE service_date COLLATE "C" BETWEEN '2026-10-02' AND '2026-10-31'
), grouped AS (
  -- grouped: per trip and day, the winning values are packed into sortable text: a fixed-width number, a separator, a JSON value
  SELECT trip_id, service_date, min(unscheduled) AS unscheduled, max(scheduled_s) AS scheduled_s,
         max(CASE WHEN unscheduled = 0 THEN route_id END COLLATE "C") AS scheduled_route,
         max((CASE WHEN route_id IS NOT NULL THEN lpad(load_ms::text, 20, '0') || chr(31) || to_json(route_id)::text END) COLLATE "C") AS route_packed,
         min((CASE WHEN event_kind = 'start' AND event_s >= extract(epoch from (service_date::date + time '07:00'))::bigint
                   THEN lpad(event_s::text, 12, '0') || lpad(load_ms::text, 20, '0') || chr(31)
                        || '[' || to_json(event_key)::text || ',' || coalesce(to_json(vehicle_id)::text, 'null') || ']' END) COLLATE "C") AS first_start,
         max((lpad(coalesce(event_s, load_s, 0)::text, 12, '0') || lpad(load_ms::text, 20, '0') || chr(31)
              || '[' || to_json(event_key)::text || ',' || coalesce(to_json(event_kind)::text, 'null') || ']') COLLATE "C") AS last_event,
         sum(CASE WHEN event_kind IS NOT NULL THEN 1 ELSE 0 END) AS known_events
  FROM events GROUP BY trip_id, service_date
), decoded AS (
  -- decoded: unpack the winners; only trips with at least one start, end or cancel report appear
  SELECT trip_id, service_date, unscheduled, scheduled_s,
         CASE WHEN unscheduled = 0 THEN scheduled_route
              WHEN route_packed IS NOT NULL THEN substr(route_packed, 22)::jsonb #>> '{}' END AS route_id,
         CASE WHEN first_start IS NOT NULL THEN substr(first_start, 1, 12)::bigint END AS actual_s,
         CASE WHEN first_start IS NOT NULL THEN substr(first_start, 34)::jsonb ->> 1 END AS vehicle_id,
         substr(last_event, 34)::jsonb ->> 1 AS last_kind
  FROM grouped WHERE known_events > 0
)
SELECT trip_id, service_date, route_id,
       to_char(to_timestamp(scheduled_s) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS scheduled_start,
       to_char(to_timestamp(actual_s) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS actual_start,
       CASE WHEN actual_s IS NOT NULL AND scheduled_s IS NOT NULL THEN actual_s - scheduled_s END AS delay_s,
       CASE last_kind WHEN 'end' THEN 'completed' WHEN 'start' THEN 'started' WHEN 'cancel' THEN 'cancelled' END AS status,
       vehicle_id, unscheduled
FROM decoded;
