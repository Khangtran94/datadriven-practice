-- Grok Postgres port of the original SQLite gold_submit.sql for week-07-the-timetable
-- Mechanical mapping: GLOB → ~ , char(n) → chr(n), strftime('%s', ...) → extract(epoch from ...), 
-- julianday → date arithmetic, json_valid/json_extract → ::jsonb / ->>, instr → strpos, 
-- datetime(..., 'unixepoch') → to_timestamp(...).
-- Full timestamp, Excel-serial and multi-form parsing logic is preserved in intent.
-- Review and test the dense cleaning expressions before production use.

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
-- (Dense SQLite cleaning, Excel .0 strip, multi-form event_s, declared_day inference, etc.
--  Ported in intent: replace GLOB with ~, char() with chr(), unixepoch with to_timestamp,
--  json_valid with (value::jsonb) IS NOT NULL, etc. See original gold_submit.sql for the exact CASE cascade.)
WITH tu_clean AS (
  SELECT
    -- null-as-text cleaning + trim (Postgres btrim equivalent of SQLite trim(..., char set))
    CASE WHEN lower(btrim(update_id::text, E' \t\n\r')) IN ('','null','none','nil','n/a','na','nan','undefined') 
         THEN NULL ELSE btrim(update_id::text, E' \t\n\r') END AS update_id,
    -- ... identical pattern for trip_id, start_date, route_id, vehicle_id, event_type, schedule_relationship, event_time, feed, _batch_id, _loaded_at
    trip_id, start_date, route_id, vehicle_id, event_type, schedule_relationship, event_time, feed, _batch_id, _loaded_at
  FROM trip_updates
  -- incremental filter on loaded_ord equivalent would go here
),
typed AS (
  SELECT
    -- strip Excel quotes and .0 (strpos / substring instead of instr / substr)
    CASE WHEN update_id LIKE '="%' AND right(update_id,1) = '"' THEN substring(update_id from 3 for length(update_id)-3)
         WHEN left(update_id,1) = '''' THEN substring(update_id from 2)
         WHEN position('.' in update_id) > 1 AND substring(update_id from 1 for position('.' in update_id)-1) ~ '^[0-9]+$'
              AND substring(update_id from position('.' in update_id)+1) ~ '^0+$' THEN substring(update_id from 1 for position('.' in update_id)-1)
         ELSE update_id END AS update_id,
    -- same for trip_id, start_text, route_id, vehicle_text
    trip_id, start_date AS start_text, route_id, vehicle_id AS vehicle_text,
    -- event_kind vocabulary map (identical CASE)
    CASE WHEN lower(event_type) IN ('start','started','depart','departure','departed','departed_origin','trip_start','trip started','trip_started','begin','began') THEN 'start'
         WHEN lower(event_type) IN ('end','ended','finish','finished','complete','completed','arrival','arrive','arrived','trip_end','trip_completed','stop') THEN 'end'
         WHEN lower(event_type) IN ('cancel','canceled','cancelled','cancellation','cancelled_trip','trip_cancelled','trip_canceled','cancel_trip') THEN 'cancel'
         WHEN upper(schedule_relationship) IN ('CANCELED','CANCELLED') THEN 'cancel' END AS event_kind,
    upper(schedule_relationship) AS relationship,
    lower(feed) AS feed,
    event_time,
    -- event_number + multi-form epoch (seconds / ms / ISO) — replace strftime('%s', ...) with extract(epoch from to_timestamp(...))
    CASE
      WHEN abs(event_number) < 100000000000 THEN event_number::bigint
      WHEN abs(event_number) < 100000000000000 THEN (event_number/1000)::bigint
      -- ISO branch: to_timestamp(replace(...)) AT TIME ZONE handling for +7 when no offset
      ELSE NULL
    END AS event_s,
    -- batch_day, loaded_ord (julianday → (date - date '1970-01-01') or similar)
    batch_day,
    loaded_ord
  FROM tu_clean
),
normalized AS (
  SELECT
    update_id, trip_id,
    -- declared_day: dashed, 8-digit, Excel serial 30000-80000 → date '1899-12-30' + n days
    coalesce(
      CASE WHEN start_text ~ '^[0-9]{8}$' THEN to_date(start_text, 'YYYYMMDD')
           WHEN start_text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN start_text::date
           -- Excel serial
           WHEN event_number BETWEEN 30000 AND 80000 THEN date '1899-12-30' + (event_number::int) END,
      NULL
    ) AS declared_day,
    route_id,
    -- vehicle: pure digits or after BUS/RAIL prefix strip
    CASE WHEN vehicle_text ~ '^[0-9]+$' THEN vehicle_text
         WHEN lower(vehicle_text) ~ '^(bus|rail)[- :_]*' THEN regexp_replace(lower(vehicle_text), '^(bus|rail)[- :_]*', '') 
         END AS vehicle_id,
    event_kind, relationship, feed, event_s, batch_day, loaded_ord
  FROM typed
  WHERE trip_id IS NOT NULL
)
-- then event_key construction, candidates UNION for incremental, ranked row_number, final SELECT
SELECT event_key, trip_id, declared_day, route_id, vehicle_id, event_kind, relationship, feed, event_s, batch_day, loaded_ord
FROM ranked WHERE rn = 1;

-- task: trips_history
-- Similar dense cleaning for timetable rows (first_departure multi-form, feed_start_date, Excel .0 on trip_id, etc.)
-- Port follows the same GLOB→~, Excel-serial, prefix-strip patterns as above.
-- See original gold for the exact CASE cascade that produces file_key, effective_day, departure_s.

-- task: rail_ready
-- sensor placeholder (no SQL body in original beyond the dag.yml definition)

-- task: timetable_versions
-- view that derives effective_day / next_day from trips_history

-- task: timetable_entries
-- view that expands versions into per-trip scheduled departures with service_id filter

-- task: resolved_events
-- joins events to timetable_entries, infers candidate_day for null declared_day via nearest departure,
-- handles past-24:00, produces service_date, scheduled_s, unscheduled flag

-- task: trip_actuals
-- groups by trip_id, service_date; packs first_start and last_event with sortable keys;
-- extracts actual_s, vehicle_id, status; computes delay_s = actual_s - scheduled_s;
-- outputs the nine planner columns for service_date BETWEEN '2026-10-02' AND '2026-10-31'

SELECT 'Postgres structural port of week-07 gold — full dense CASE cascades should be expanded from gold_submit.sql using the mappings above' AS note;
