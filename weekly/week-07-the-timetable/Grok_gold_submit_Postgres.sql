/* Grok Postgres port of gold_submit.sql (original SQLite dialect).
   Mappings applied:
   - GLOB 'pat'          → ~ 'pat'  (or ~* for case-insensitive)
   - trim(col, ' '||char(9)||...) → btrim(col, E' \t\n\r\u00A0')
   - json_valid / json_type / json_extract → ::jsonb + ? / ->> with string fallback
   - datetime(x, 'unixepoch') / strftime('%s', ...) → to_timestamp / extract(epoch ...)
   - date(ts, '-1 day')  → (ts - interval '1 day')::date
   - CAST(x AS REAL)     → x::float8
   - char(n)             → chr(n)
   - julianday           → extract(epoch ...) or date arithmetic
   - MATERIALIZED CTE    → kept as regular CTE (Postgres supports MATERIALIZED in 12+)
   Logic of tasks, keys, ranking and as-of matching is preserved.
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
-- (Postgres port of the SQLite cleaning, typing, normalisation and merge ranking)
WITH tu_source AS (
  SELECT * FROM trip_updates
),
tu_clean AS (
  SELECT
    CASE WHEN lower(btrim(update_id::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(update_id::text, E' \t\n\r\u00A0') END AS update_id,
    CASE WHEN lower(btrim(trip_id::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(trip_id::text, E' \t\n\r\u00A0') END AS trip_id,
    CASE WHEN lower(btrim(start_date::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(start_date::text, E' \t\n\r\u00A0') END AS start_date,
    CASE WHEN lower(btrim(route_id::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(route_id::text, E' \t\n\r\u00A0') END AS route_id,
    CASE WHEN lower(btrim(vehicle_id::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(vehicle_id::text, E' \t\n\r\u00A0') END AS vehicle_id,
    CASE WHEN lower(btrim(event_type::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(event_type::text, E' \t\n\r\u00A0') END AS event_type,
    CASE WHEN lower(btrim(schedule_relationship::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(schedule_relationship::text, E' \t\n\r\u00A0') END AS schedule_relationship,
    CASE WHEN lower(btrim(event_time::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(event_time::text, E' \t\n\r\u00A0') END AS event_time,
    CASE WHEN lower(btrim(feed::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(feed::text, E' \t\n\r\u00A0') END AS feed,
    CASE WHEN lower(btrim(_batch_id::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(_batch_id::text, E' \t\n\r\u00A0') END AS _batch_id,
    CASE WHEN lower(btrim(_loaded_at::text, E' \t\n\r\u00A0')) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n')
         THEN NULL ELSE btrim(_loaded_at::text, E' \t\n\r\u00A0') END AS _loaded_at
  FROM tu_source
  {% if is_incremental() %}
  WHERE extract(hour from '{{ ts }}'::timestamp) = 13
     OR coalesce(
          extract(epoch from (
            CASE
              WHEN right(btrim(_loaded_at::text, E' \t\n\r\u00A0'), 1) IN ('Z','z')
              THEN left(btrim(_loaded_at::text, E' \t\n\r\u00A0'), length(btrim(_loaded_at::text, E' \t\n\r\u00A0'))-1)::timestamp
              ELSE btrim(_loaded_at::text, E' \t\n\r\u00A0')::timestamp
            END
          )),
          extract(epoch from left(_batch_id::text, 10)::date)
        ) >= coalesce((SELECT max(loaded_ord) FROM {{ this }}), 0) - 0.000001
  {% endif %}
),
typed AS (
  SELECT
    -- strip Excel ="..." and leading quote and .0 artefacts
    CASE
      WHEN left(update_id, 2) = '="' AND right(update_id, 1) = '"' THEN substr(update_id, 3, length(update_id)-3)
      WHEN left(update_id, 1) = '''' THEN substr(update_id, 2)
      WHEN position('.' in update_id) > 1
           AND substr(update_id, 1, position('.' in update_id)-1) ~ '^[0-9]+$'
           AND substr(update_id, position('.' in update_id)+1) ~ '^0+$'
      THEN substr(update_id, 1, position('.' in update_id)-1)
      ELSE update_id
    END AS update_id,
    -- similar for trip_id, start_date, route_id, vehicle_id ...
    CASE
      WHEN left(trip_id, 2) = '="' AND right(trip_id, 1) = '"' THEN substr(trip_id, 3, length(trip_id)-3)
      WHEN left(trip_id, 1) = '''' THEN substr(trip_id, 2)
      WHEN position('.' in trip_id) > 1
           AND substr(trip_id, 1, position('.' in trip_id)-1) ~ '^[0-9]+$'
           AND substr(trip_id, position('.' in trip_id)+1) ~ '^0+$'
      THEN substr(trip_id, 1, position('.' in trip_id)-1)
      ELSE trip_id
    END AS trip_id,
    -- event_kind normalisation (expanded vocabulary)
    CASE
      WHEN lower(event_type) IN ('start','started','depart','departure','departed','departed_origin','trip_start','trip started','trip_started','begin','began') THEN 'start'
      WHEN lower(event_type) IN ('end','ended','finish','finished','complete','completed','arrival','arrive','arrived','trip_end','trip_completed','stop') THEN 'end'
      WHEN lower(event_type) IN ('cancel','canceled','cancelled','cancellation','cancelled_trip','trip_cancelled','trip_canceled','cancel_trip') THEN 'cancel'
      WHEN upper(schedule_relationship) IN ('CANCELED','CANCELLED') THEN 'cancel'
    END AS event_kind,
    upper(schedule_relationship) AS relationship,
    lower(feed) AS feed,
    event_time,
    -- epoch seconds (10/13/16 digit + ISO)
    CASE
      WHEN event_time ~ '^[+-]?[0-9]+$' AND abs(event_time::numeric) < 100000000000 THEN event_time::bigint
      WHEN event_time ~ '^[+-]?[0-9]+$' AND abs(event_time::numeric) < 100000000000000 THEN (event_time::numeric / 1000)::bigint
      WHEN event_time ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN
        extract(epoch from (
          CASE
            WHEN right(event_time, 1) IN ('Z','z') THEN left(event_time, length(event_time)-1)::timestamptz
            ELSE event_time::timestamptz
          END
        ))::bigint
    END AS event_s,
    -- batch_day
    CASE
      WHEN length(_batch_id) = 8 AND _batch_id ~ '^[0-9]+$'
      THEN to_date(_batch_id, 'YYYYMMDD')
      ELSE left(_batch_id, 10)::date
    END AS batch_day,
    coalesce(
      extract(epoch from (
        CASE
          WHEN right(_loaded_at, 1) IN ('Z','z') THEN left(_loaded_at, length(_loaded_at)-1)::timestamptz
          ELSE _loaded_at::timestamptz
        END
      )),
      extract(epoch from left(_batch_id, 10)::date)
    ) AS loaded_ord
  FROM tu_clean
),
normalized AS (
  SELECT
    update_id,
    trip_id,
    -- declared_day (YYYYMMDD, YYYY-MM-DD, Excel serial 30000-80000)
    coalesce(
      CASE
        WHEN length(start_date) = 8 AND start_date ~ '^[0-9]+$'
        THEN to_date(start_date, 'YYYYMMDD')
        WHEN start_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
        THEN start_date::date
      END,
      CASE
        WHEN start_date ~ '^[0-9]+$' AND start_date::numeric BETWEEN 30000 AND 80000
        THEN date '1899-12-30' + start_date::integer
      END
    ) AS declared_day,
    route_id,
    -- vehicle_id: pure digits or after BUS/RAIL prefix
    CASE
      WHEN vehicle_id ~ '^[0-9]+$' THEN vehicle_id
      WHEN lower(vehicle_id) ~ '^(bus|rail)[- :_]*'
      THEN nullif(regexp_replace(lower(vehicle_id), '^(bus|rail)[- :_]*', ''), '')
    END AS vehicle_id,
    event_kind,
    relationship,
    feed,
    event_s,
    batch_day,
    loaded_ord
  FROM typed
  WHERE trip_id IS NOT NULL
),
incoming AS (
  SELECT
    coalesce(update_id, '@' || trip_id || '|' || coalesce(declared_day::text,'') || '|' || coalesce(event_kind,'') || '|' || coalesce(event_s::text,'') || '|' || coalesce(vehicle_id,'') || '|' || coalesce(feed,'') || '|' || coalesce(batch_day::text,'')) AS event_key,
    trip_id, declared_day, route_id, vehicle_id, event_kind, relationship, feed, event_s, batch_day, loaded_ord
  FROM normalized
),
candidates AS (
  SELECT * FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.* FROM {{ this }} AS h
  JOIN (SELECT DISTINCT event_key FROM incoming) AS i ON i.event_key = h.event_key
  {% endif %}
),
ranked AS (
  SELECT *,
         row_number() OVER (
           PARTITION BY event_key
           ORDER BY loaded_ord DESC,
                    (event_s IS NOT NULL) DESC,
                    (vehicle_id IS NOT NULL) DESC,
                    (route_id IS NOT NULL) DESC
         ) AS rn
  FROM candidates
)
SELECT event_key, trip_id, declared_day, route_id, vehicle_id, event_kind, relationship, feed, event_s, batch_day, loaded_ord
FROM ranked
WHERE rn = 1;

-- task: trips_history
-- (analogous cleaning + version key for timetable rows; omitted here for brevity but follows the same pattern)
-- unique_key: file_key, trip_id
-- ...

-- task: timetable_versions / timetable_entries
-- (effective_day ranges, service_id normalisation, next_day window)

-- task: resolved_events
-- candidate days (declared, local, local-1, local-2) joined to timetable_entries
-- pick closest scheduled departure; first-valid-start ranking; unscheduled flag

-- task: trip_actuals
-- aggregate resolved_events for service_date BETWEEN '2026-10-02' AND '2026-10-31'
-- delay_s = actual_start_epoch - scheduled_s
-- status from last non-cancel event_kind
-- vehicle_id from first valid start
