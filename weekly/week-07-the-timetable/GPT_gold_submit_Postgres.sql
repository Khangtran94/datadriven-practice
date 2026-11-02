/*
  Week 7 — The Timetable
  PostgreSQL companion translation of gold_submit.sql (source dialect: SQLite).

  Requirements: PostgreSQL 16+ (pg_input_is_valid).
  This file contains SQL task queries only. DAG scheduling, sensors, incremental
  materialization/merge behavior, task dependencies, and the Jinja runner remain
  the responsibility of the original orchestration environment.

  Validation status: static translation only. No PostgreSQL runtime or sample
  database was available, so execution and sample-output comparison were not
  performed. Review the runner's incremental merge contract before deployment.
*/

-- task: trip_updates_history
WITH raw AS (
    SELECT
        NULLIF(btrim(update_id::text), '') AS update_id_raw,
        NULLIF(btrim(trip_id::text), '') AS trip_id_raw,
        NULLIF(btrim(start_date::text), '') AS start_date_raw,
        NULLIF(btrim(route_id::text), '') AS route_id_raw,
        NULLIF(btrim(vehicle_id::text), '') AS vehicle_id_raw,
        NULLIF(btrim(event_type::text), '') AS event_type_raw,
        NULLIF(btrim(schedule_relationship::text), '') AS relationship_raw,
        NULLIF(btrim(event_time::text), '') AS event_time_raw,
        NULLIF(btrim(feed::text), '') AS feed_raw,
        NULLIF(btrim(_batch_id::text), '') AS batch_id_raw,
        NULLIF(btrim(_loaded_at::text), '') AS loaded_at_raw
    FROM trip_updates
),
clean AS MATERIALIZED (
    SELECT
        CASE WHEN lower(update_id_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE update_id_raw END AS update_id,
        CASE WHEN lower(trip_id_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE trip_id_raw END AS trip_id,
        CASE WHEN lower(start_date_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE start_date_raw END AS start_date,
        CASE WHEN lower(route_id_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE route_id_raw END AS route_id,
        CASE WHEN lower(vehicle_id_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE vehicle_id_raw END AS vehicle_id,
        CASE WHEN lower(event_type_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE event_type_raw END AS event_type,
        CASE WHEN lower(relationship_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE relationship_raw END AS relationship,
        CASE WHEN lower(event_time_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE event_time_raw END AS event_time,
        CASE WHEN lower(feed_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE feed_raw END AS feed,
        CASE WHEN lower(batch_id_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE batch_id_raw END AS batch_id,
        CASE WHEN lower(loaded_at_raw) IN ('null','none','nil','n/a','na','nan','undefined','\\n','\\\\n') THEN NULL ELSE loaded_at_raw END AS loaded_at
    FROM raw
),
typed AS MATERIALIZED (
    SELECT
        regexp_replace(regexp_replace(update_id, '^="(.*)"$', '\\1'), '^''', '') AS update_id,
        regexp_replace(regexp_replace(trip_id, '^="(.*)"$', '\\1'), '^''', '') AS trip_id,
        regexp_replace(regexp_replace(start_date, '^="(.*)"$', '\\1'), '^''', '') AS start_text,
        regexp_replace(regexp_replace(route_id, '^="(.*)"$', '\\1'), '^''', '') AS route_id,
        regexp_replace(regexp_replace(vehicle_id, '^="(.*)"$', '\\1'), '^''', '') AS vehicle_text,
        CASE
          WHEN lower(event_type) IN ('start','started','depart','departure','departed','departed_origin','trip_start','trip started','trip_started','begin','began') THEN 'start'
          WHEN lower(event_type) IN ('end','ended','finish','finished','complete','completed','arrival','arrive','arrived','trip_end','trip_completed','stop') THEN 'end'
          WHEN lower(event_type) IN ('cancel','canceled','cancelled','cancellation','cancelled_trip','trip_cancelled','trip_canceled','cancel_trip') THEN 'cancel'
          WHEN upper(relationship) IN ('CANCELED','CANCELLED') THEN 'cancel'
        END AS event_kind,
        upper(relationship) AS relationship,
        lower(feed) AS feed,
        event_time,
        batch_id,
        loaded_at,
        CASE
          WHEN length(batch_id)=8 AND batch_id ~ '^[0-9]{8}$'
               AND pg_input_is_valid(substr(batch_id,1,4)||'-'||substr(batch_id,5,2)||'-'||substr(batch_id,7,2),'date')
            THEN (substr(batch_id,1,4)||'-'||substr(batch_id,5,2)||'-'||substr(batch_id,7,2))::date
          WHEN left(batch_id,10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
               AND pg_input_is_valid(left(batch_id,10),'date') THEN left(batch_id,10)::date
        END AS batch_day,
        CASE
          WHEN loaded_at IS NOT NULL AND pg_input_is_valid(loaded_at,'timestamptz')
            THEN extract(epoch FROM loaded_at::timestamptz)::numeric / 86400
          WHEN batch_id IS NOT NULL AND pg_input_is_valid(left(batch_id,10),'date')
            THEN extract(epoch FROM left(batch_id,10)::date::timestamp AT TIME ZONE 'UTC')::numeric / 86400
        END AS loaded_ord,
        CASE
          WHEN start_text ~ '^[0-9]{8}$'
               AND pg_input_is_valid(substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2),'date')
            THEN (substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2))::date
          WHEN start_text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
               AND pg_input_is_valid(left(start_text,10),'date') THEN left(start_text,10)::date
          WHEN start_text ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
               AND pg_input_is_valid(replace(start_text,'/','-'),'date') THEN replace(start_text,'/','-')::date
          WHEN start_text ~ '^[0-9]+(\\.[0-9]+)?$'
               AND start_text::numeric BETWEEN 30000 AND 80000
            THEN date '1899-12-30' + floor(start_text::numeric)::integer
        END AS declared_day,
        CASE
          WHEN vehicle_text ~ '^[0-9]+$' THEN vehicle_text
          WHEN lower(vehicle_text) ~ '^(bus|rail)[ -:_]*[0-9]+$'
            THEN regexp_replace(vehicle_text,'^(?i:bus|rail)[ -:_]*','')
        END AS vehicle_id,
        CASE
          WHEN event_time ~ '^[+-]?[0-9]+(\\.[0-9]+)?$' THEN
            CASE
              WHEN abs(event_time::numeric) < 100000000000 THEN trunc(event_time::numeric)::bigint
              WHEN abs(event_time::numeric) < 100000000000000 THEN trunc(event_time::numeric/1000)::bigint
              WHEN abs(event_time::numeric) < 100000000000000000 THEN trunc(event_time::numeric/1000000)::bigint
              WHEN abs(event_time::numeric) < 100000000000000000000 THEN trunc(event_time::numeric/1000000000)::bigint
            END
          WHEN event_time IS NOT NULL AND pg_input_is_valid(event_time,'timestamptz')
            THEN extract(epoch FROM event_time::timestamptz)::bigint
          WHEN event_time IS NOT NULL AND pg_input_is_valid(event_time,'timestamp')
            THEN extract(epoch FROM ((event_time::timestamp + interval '7 hours') AT TIME ZONE 'UTC'))::bigint
        END AS event_s
    FROM clean
),
incoming AS (
    SELECT
        coalesce(update_id, '@'||jsonb_build_array(trip_id,declared_day,event_kind,event_s,vehicle_id,feed,batch_day)::text) AS event_key,
        trip_id,declared_day,route_id,vehicle_id,event_kind,relationship,feed,event_s,batch_day,loaded_ord
    FROM typed
    WHERE trip_id IS NOT NULL
),
candidates AS (
    SELECT * FROM incoming
    {% if is_incremental() %}
    UNION ALL
    SELECT h.* FROM {{ this }} AS h
    JOIN (SELECT DISTINCT event_key FROM incoming) AS i USING (event_key)
    {% endif %}
),
ranked AS (
    SELECT *, row_number() OVER (
        PARTITION BY event_key
        ORDER BY loaded_ord DESC NULLS LAST, (event_s IS NOT NULL) DESC,
                 (vehicle_id IS NOT NULL) DESC, (route_id IS NOT NULL) DESC
    ) AS rn
    FROM candidates
)
SELECT event_key,trip_id,declared_day,route_id,vehicle_id,event_kind,relationship,feed,event_s,batch_day,loaded_ord
FROM ranked
WHERE rn=1;

-- task: trips_history
WITH raw AS (
    SELECT
        NULLIF(btrim(trip_id::text),'') AS trip_id_raw,
        NULLIF(btrim(route_id::text),'') AS route_id_raw,
        NULLIF(btrim(service_id::text),'') AS service_id_raw,
        NULLIF(btrim(direction_id::text),'') AS direction_id_raw,
        NULLIF(btrim(trip_headsign::text),'') AS trip_headsign_raw,
        NULLIF(btrim(first_departure::text),'') AS departure_raw,
        NULLIF(btrim(feed_version::text),'') AS feed_version,
        NULLIF(btrim(feed_start_date::text),'') AS start_date_raw,
        NULLIF(btrim(_batch_id::text),'') AS batch_id,
        NULLIF(btrim(_loaded_at::text),'') AS loaded_at
    FROM trips
),
typed AS MATERIALIZED (
    SELECT
        regexp_replace(regexp_replace(trip_id_raw,'^="(.*)"$','\\1'),'^''','') AS trip_id,
        regexp_replace(regexp_replace(route_id_raw,'^="(.*)"$','\\1'),'^''','') AS route_id,
        upper(service_id_raw) AS service_id,
        direction_id_raw AS direction_id,
        trip_headsign_raw AS trip_headsign,
        regexp_replace(regexp_replace(departure_raw,'^="(.*)"$','\\1'),'^''','') AS departure_text,
        feed_version,
        regexp_replace(regexp_replace(start_date_raw,'^="(.*)"$','\\1'),'^''','') AS start_text,
        batch_id,loaded_at,
        CASE
          WHEN length(batch_id)=8 AND batch_id ~ '^[0-9]{8}$'
               AND pg_input_is_valid(substr(batch_id,1,4)||'-'||substr(batch_id,5,2)||'-'||substr(batch_id,7,2),'date')
            THEN (substr(batch_id,1,4)||'-'||substr(batch_id,5,2)||'-'||substr(batch_id,7,2))::date
          WHEN left(batch_id,10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
               AND pg_input_is_valid(left(batch_id,10),'date') THEN left(batch_id,10)::date
        END AS batch_day,
        CASE WHEN loaded_at IS NOT NULL AND pg_input_is_valid(loaded_at,'timestamptz')
             THEN extract(epoch FROM loaded_at::timestamptz)::numeric / 86400
             WHEN batch_id IS NOT NULL AND pg_input_is_valid(left(batch_id,10),'date')
             THEN extract(epoch FROM left(batch_id,10)::date::timestamp AT TIME ZONE 'UTC')::numeric / 86400 END AS loaded_ord
    FROM raw
),
parsed AS MATERIALIZED (
    SELECT *,
        CASE
          WHEN start_text ~ '^[0-9]{8}$'
               AND pg_input_is_valid(substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2),'date')
            THEN (substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2))::date
          WHEN left(start_text,10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
               AND pg_input_is_valid(left(start_text,10),'date') THEN left(start_text,10)::date
          WHEN start_text ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
               AND pg_input_is_valid(replace(start_text,'/','-'),'date') THEN replace(start_text,'/','-')::date
          WHEN start_text ~ '^[0-9]+(\\.[0-9]+)?$' AND start_text::numeric BETWEEN 30000 AND 80000
            THEN date '1899-12-30' + floor(start_text::numeric)::integer
          WHEN start_text IS NOT NULL AND pg_input_is_valid(start_text,'date') THEN start_text::date
          ELSE batch_day
        END AS effective_day,
        CASE
          WHEN departure_text ~ '^[0-9]{1,3}:[0-9]{1,2}(:[0-9]{1,2})?\\s*(am|pm)?$' THEN
            CASE
              WHEN split_part(lower(departure_text),' ',1) ~ '^[0-9]{1,3}:[0-9]{1,2}(:[0-9]{1,2})?$'
              THEN
                CASE
                  WHEN lower(departure_text) ~ '(am|pm)$' THEN
                    ((CASE WHEN lower(departure_text) ~ 'pm$'
                           THEN (split_part(split_part(lower(departure_text),' ',1),':',1)::int % 12)+12
                           ELSE split_part(split_part(lower(departure_text),' ',1),':',1)::int % 12 END) * 3600)
                    + split_part(split_part(lower(departure_text),' ',1),':',2)::int * 60
                    + coalesce(nullif(split_part(split_part(lower(departure_text),' ',1),':',3),''),'0')::int
                  ELSE split_part(departure_text,':',1)::int * 3600
                    + split_part(departure_text,':',2)::int * 60
                    + coalesce(nullif(split_part(departure_text,':',3),''),'0')::int
                END
            END
          WHEN departure_text ~ '^[0-9]+(\\.[0-9]+)?$' AND departure_text::numeric >= 0 AND departure_text::numeric < 7
            THEN round(departure_text::numeric * 86400)::int
        END AS departure_s
    FROM typed
    WHERE trip_id IS NOT NULL
),
incoming AS (
    SELECT
        jsonb_build_array(feed_version,effective_day,batch_day,loaded_ord)::text AS file_key,
        trip_id,route_id,
        CASE WHEN service_id IN ('WKD','WEEKDAY','WEEKDAYS') THEN 'WKD'
             WHEN service_id IN ('SAT','SATURDAY') THEN 'SAT'
             WHEN service_id IN ('SUN','SUNDAY') THEN 'SUN'
             ELSE service_id END AS service_id,
        effective_day,feed_version,batch_day,loaded_ord,departure_s
    FROM parsed
    WHERE effective_day IS NOT NULL
),
candidates AS (
    SELECT * FROM incoming
    {% if is_incremental() %}
    UNION ALL
    SELECT h.* FROM {{ this }} AS h
    JOIN (SELECT DISTINCT file_key,trip_id FROM incoming) AS i
      ON i.file_key=h.file_key AND i.trip_id=h.trip_id
    {% endif %}
),
ranked AS (
    SELECT *,row_number() OVER (
        PARTITION BY file_key,trip_id
        ORDER BY (departure_s IS NOT NULL) DESC,(route_id IS NOT NULL) DESC
    ) AS rn
    FROM candidates
)
SELECT file_key,trip_id,route_id,service_id,effective_day,feed_version,batch_day,loaded_ord,departure_s
FROM ranked
WHERE rn=1;

-- task: rail_ready (sensor query; orchestration still owns its 12-hour timeout/soft-fail)
SELECT 1
WHERE EXISTS (
    SELECT 1
    FROM trip_updates
    WHERE lower(btrim(feed::text)) IN ('rail','light_rail','light rail','lrt','tram')
      AND CASE
            WHEN length(btrim(_batch_id::text))=8
             AND btrim(_batch_id::text) ~ '^[0-9]{8}$'
             AND pg_input_is_valid(substr(btrim(_batch_id::text),1,4)||'-'||substr(btrim(_batch_id::text),5,2)||'-'||substr(btrim(_batch_id::text),7,2),'date')
              THEN (substr(btrim(_batch_id::text),1,4)||'-'||substr(btrim(_batch_id::text),5,2)||'-'||substr(btrim(_batch_id::text),7,2))::date
            WHEN pg_input_is_valid(left(btrim(_batch_id::text),10),'date')
              THEN left(btrim(_batch_id::text),10)::date
          END = (('{{ ts }}'::timestamptz AT TIME ZONE 'UTC')::date - 1)
);

-- task: timetable_versions
WITH files AS (
    SELECT file_key,effective_day,max(loaded_ord) AS loaded_ord,
           max(batch_day) AS batch_day,max(feed_version) AS feed_version
    FROM trips_history
    GROUP BY file_key,effective_day
),
ranked AS (
    SELECT *,row_number() OVER (
        PARTITION BY effective_day
        ORDER BY loaded_ord DESC NULLS LAST,batch_day DESC,feed_version DESC,file_key DESC
    ) AS rn
    FROM files
)
SELECT file_key,effective_day,
       lead(effective_day,1,date '9999-12-31') OVER (ORDER BY effective_day) AS next_day
FROM ranked
WHERE rn=1;

-- task: timetable_entries
SELECT h.trip_id,h.route_id,h.service_id,h.departure_s,v.effective_day,v.next_day
FROM timetable_versions AS v
JOIN trips_history AS h ON h.file_key=v.file_key;

-- task: resolved_events
WITH source AS MATERIALIZED (
    SELECT *,
           ((to_timestamp(event_s) AT TIME ZONE 'UTC') - interval '7 hours')::date AS local_day
    FROM trip_updates_history
),
candidates AS (
    SELECT *,coalesce(declared_day,local_day,batch_day) AS candidate_day
    FROM source
    UNION ALL
    SELECT *,local_day - 1 AS candidate_day
    FROM source WHERE declared_day IS NULL AND local_day IS NOT NULL
    UNION ALL
    SELECT *,local_day - 2 AS candidate_day
    FROM source WHERE declared_day IS NULL AND local_day IS NOT NULL
),
matched AS (
    SELECT c.*,t.route_id AS scheduled_route,t.departure_s,t.trip_id AS scheduled_id,
           extract(epoch FROM (c.candidate_day::timestamp AT TIME ZONE 'UTC' + interval '7 hours'))::bigint
             + t.departure_s AS scheduled_s,
           row_number() OVER (
             PARTITION BY c.event_key
             ORDER BY (t.trip_id IS NOT NULL) DESC,
               CASE WHEN c.declared_day IS NOT NULL THEN 0
                    ELSE abs(c.event_s - (
                      extract(epoch FROM (c.candidate_day::timestamp AT TIME ZONE 'UTC' + interval '7 hours'))::bigint
                      + t.departure_s)) END,
               c.candidate_day DESC
           ) AS rn
    FROM candidates AS c
    LEFT JOIN timetable_entries AS t
      ON t.trip_id=c.trip_id
     AND c.candidate_day>=t.effective_day
     AND c.candidate_day<t.next_day
     AND (t.service_id IS NULL OR t.service_id NOT IN ('WKD','SAT','SUN')
          OR (t.service_id='WKD' AND extract(isodow FROM c.candidate_day) BETWEEN 1 AND 5)
          OR (t.service_id='SAT' AND extract(isodow FROM c.candidate_day)=6)
          OR (t.service_id='SUN' AND extract(isodow FROM c.candidate_day)=7))
     AND (c.declared_day IS NOT NULL OR abs(c.event_s - (
          extract(epoch FROM (c.candidate_day::timestamp AT TIME ZONE 'UTC' + interval '7 hours'))::bigint
          + t.departure_s)) <= 43200)
),
anchored AS (
    SELECT *,
       min(CASE WHEN event_kind='start'
                 AND (declared_day IS NULL OR event_s >=
                      extract(epoch FROM (declared_day::timestamp AT TIME ZONE 'UTC' + interval '7 hours'))::bigint)
                THEN event_s END)
       OVER (PARTITION BY trip_id,coalesce(declared_day,candidate_day),scheduled_id IS NULL) AS extra_start
    FROM matched
    WHERE rn=1
)
SELECT event_key,trip_id,
       CASE WHEN scheduled_id IS NOT NULL THEN candidate_day
            ELSE coalesce(((to_timestamp(extra_start) AT TIME ZONE 'UTC') - interval '7 hours')::date,
                          declared_day,local_day,batch_day) END AS service_date,
       CASE WHEN scheduled_id IS NOT NULL THEN scheduled_route ELSE route_id END AS route_id,
       scheduled_s,event_s,event_kind,vehicle_id,loaded_ord,
       CASE WHEN scheduled_id IS NULL THEN 1 ELSE 0 END AS unscheduled
FROM anchored;

-- task: trip_actuals
WITH events AS MATERIALIZED (
    SELECT *
    FROM resolved_events
    WHERE service_date BETWEEN date '2026-10-02' AND date '2026-10-31'
),
grouped AS (
    SELECT
        trip_id,service_date,min(unscheduled) AS unscheduled,max(scheduled_s) AS scheduled_s,
        max(CASE WHEN unscheduled=0 THEN route_id END) AS scheduled_route,
        (array_agg(route_id ORDER BY loaded_ord DESC NULLS LAST,event_key DESC)
          FILTER (WHERE route_id IS NOT NULL))[1] AS latest_feed_route,
        (array_agg(event_s ORDER BY event_s,loaded_ord,event_key)
          FILTER (WHERE event_kind='start' AND event_s >=
            extract(epoch FROM (service_date::timestamp AT TIME ZONE 'UTC' + interval '7 hours'))::bigint))[1] AS actual_s,
        (array_agg(vehicle_id ORDER BY event_s,loaded_ord,event_key)
          FILTER (WHERE event_kind='start' AND event_s >=
            extract(epoch FROM (service_date::timestamp AT TIME ZONE 'UTC' + interval '7 hours'))::bigint))[1] AS first_vehicle,
        (array_agg(event_kind ORDER BY event_s DESC NULLS LAST,loaded_ord DESC NULLS LAST,event_key DESC)
          FILTER (WHERE event_kind IS NOT NULL))[1] AS last_kind,
        count(*) FILTER (WHERE event_kind IS NOT NULL) AS known_events
    FROM events
    GROUP BY trip_id,service_date
),
decoded AS (
    SELECT trip_id,service_date,unscheduled,scheduled_s,
           CASE WHEN unscheduled=0 THEN scheduled_route ELSE latest_feed_route END AS route_id,
           actual_s,first_vehicle AS vehicle_id,last_kind
    FROM grouped
    WHERE known_events>0
)
SELECT
    trip_id,service_date::text AS service_date,route_id,
    CASE WHEN scheduled_s IS NOT NULL
         THEN to_char(to_timestamp(scheduled_s) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') END AS scheduled_start,
    CASE WHEN actual_s IS NOT NULL
         THEN to_char(to_timestamp(actual_s) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') END AS actual_start,
    CASE WHEN actual_s IS NOT NULL AND scheduled_s IS NOT NULL THEN actual_s-scheduled_s END AS delay_s,
    CASE last_kind WHEN 'end' THEN 'completed' WHEN 'start' THEN 'started' WHEN 'cancel' THEN 'cancelled' END AS status,
    vehicle_id,unscheduled
FROM decoded;
