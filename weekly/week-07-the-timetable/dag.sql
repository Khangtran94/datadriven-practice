/* dag.yml
dag: the_timetable
schedule: nightly           # 13:00 UTC
tasks:
  trip_updates_history:
    materialized: incremental
    unique_key: trip_update_key
    depends_on: [trip_updates]
  trips_history:
    materialized: incremental
    unique_key: trip_key
    depends_on: [trips]
  transform_trip:
    materialized: table
    depends_on: [trips_history]
  transform_update:
    materialized: table
    depends_on: [trip_updates_history]
  trip_actuals:
    materialized: table
    depends_on: [transform_update, transform_trip]
*/

-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after

-- task: trip_updates_history
-- Replace null raw data
WITH replace_null AS (
    SELECT
        CASE WHEN lower(trim(update_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(update_id, ' '||char(9,10,13)) END AS update_id,
        CASE WHEN lower(trim(trip_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(trip_id, ' '||char(9,10,13)) END AS trip_id,
        CASE WHEN lower(trim(start_date, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(start_date, ' '||char(9,10,13)) END AS start_date,
        CASE WHEN lower(trim(route_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(route_id, ' '||char(9,10,13)) END AS route_id,
        CASE WHEN lower(trim(vehicle_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(vehicle_id, ' '||char(9,10,13)) END AS vehicle_id,
        CASE WHEN lower(trim(event_type, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(event_type, ' '||char(9,10,13)) END AS event_type,
        CASE WHEN lower(trim(schedule_relationship, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(schedule_relationship, ' '||char(9,10,13)) END AS schedule_relationship,
        CASE WHEN lower(trim(event_time, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(event_time, ' '||char(9,10,13)) END AS event_time,
        CASE WHEN lower(trim(feed, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(feed, ' '||char(9,10,13)) END AS feed,
        CASE WHEN lower(trim(_batch_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(_batch_id, ' '||char(9,10,13)) END AS batch_id,
        CASE WHEN lower(trim(_loaded_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(_loaded_at, ' '||char(9,10,13)) END AS load_at
    FROM trip_updates
),

-- Unique key per row
key_trip_updates AS (
    SELECT
        COALESCE(r.update_id, '') || '|' ||
        COALESCE(r.trip_id, '') || '|' ||
        COALESCE(r.start_date, '') || '|' ||
        COALESCE(r.route_id, '') || '|' ||
        COALESCE(r.vehicle_id, '') || '|' ||
        COALESCE(r.event_type, '') || '|' ||
        COALESCE(r.schedule_relationship, '') || '|' ||
        COALESCE(r.event_time, '') || '|' ||
        COALESCE(r.feed, '') AS trip_update_key,
        r.*
    FROM replace_null AS r
),

-- Keep the latest batch_id / load_at per key
rownum_key AS (
    SELECT k.*,
           ROW_NUMBER() OVER (PARTITION BY trip_update_key ORDER BY batch_id DESC, load_at DESC) AS rn
    FROM key_trip_updates AS k
),

dedup_key AS (
    SELECT trip_update_key, update_id, trip_id, start_date, route_id, vehicle_id,
           event_type, schedule_relationship, event_time, feed, batch_id, load_at
    FROM rownum_key
    WHERE rn = 1
),

-- Incremental: only insert keys not already in history
merge_incremental AS (
    SELECT d.*
    FROM dedup_key AS d
    {% if is_incremental() %}
    LEFT JOIN {{ this }} AS x
      ON x.trip_update_key = d.trip_update_key
    WHERE x.trip_update_key IS NULL
    {% endif %}
)

SELECT * FROM merge_incremental;

-- task: trips_history
-- Replace null raw data
WITH replace_null AS (
    SELECT
        CASE WHEN lower(trim(trip_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(trip_id, ' '||char(9,10,13)) END AS trip_id,
        CASE WHEN lower(trim(route_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(route_id, ' '||char(9,10,13)) END AS route_id,
        CASE WHEN lower(trim(service_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(service_id, ' '||char(9,10,13)) END AS service_id,
        CASE WHEN lower(trim(direction_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(direction_id, ' '||char(9,10,13)) END AS direction_id,
        CASE WHEN lower(trim(trip_headsign, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(trip_headsign, ' '||char(9,10,13)) END AS trip_headsign,
        CASE WHEN lower(trim(first_departure, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(first_departure, ' '||char(9,10,13)) END AS first_departure,
        CASE WHEN lower(trim(feed_version, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(feed_version, ' '||char(9,10,13)) END AS feed_version,
        CASE WHEN lower(trim(feed_start_date, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(feed_start_date, ' '||char(9,10,13)) END AS feed_start_date,
        CASE WHEN lower(trim(_batch_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(_batch_id, ' '||char(9,10,13)) END AS batch_id,
        CASE WHEN lower(trim(_loaded_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(_loaded_at, ' '||char(9,10,13)) END AS load_at
    FROM trips
),

key_trips AS (
    SELECT
        COALESCE(r.trip_id, '') || '|' ||
        COALESCE(r.route_id, '') || '|' ||
        COALESCE(r.service_id, '') || '|' ||
        COALESCE(r.direction_id, '') || '|' ||
        COALESCE(r.trip_headsign, '') || '|' ||
        COALESCE(r.first_departure, '') || '|' ||
        COALESCE(r.feed_version, '') || '|' ||
        COALESCE(r.feed_start_date, '') AS trip_key,
        r.*
    FROM replace_null AS r
),

rownum_key AS (
    SELECT k.*,
           ROW_NUMBER() OVER (PARTITION BY trip_key ORDER BY batch_id DESC, load_at DESC) AS rn
    FROM key_trips AS k
),

dedup_key AS (
    SELECT trip_key, trip_id, route_id, service_id, direction_id, trip_headsign,
           first_departure, feed_version, feed_start_date, batch_id, load_at
    FROM rownum_key
    WHERE rn = 1
),

merge_incremental AS (
    SELECT d.*
    FROM dedup_key AS d
    {% if is_incremental() %}
    LEFT JOIN {{ this }} AS x
      ON x.trip_key = d.trip_key
    WHERE x.trip_key IS NULL
    {% endif %}
)

SELECT * FROM merge_incremental;

-- task: transform_trip
WITH clear AS (
    SELECT
        CASE WHEN trip_id NOT GLOB '*[^0-9]*' AND trip_id <> '' AND length(ltrim(trip_id, '0')) BETWEEN 1 AND 7
             THEN printf('%07d', CAST(ltrim(trip_id, '0') AS INTEGER))
             WHEN trip_id NOT GLOB '*[^0-9]*' AND trip_id <> '' AND length(ltrim(trip_id, '0')) = 0
             THEN '0000000' END AS trip_id,

        CAST(route_id AS TEXT) AS route_id,

        CASE
            WHEN upper(service_id) IN ('WKD','WEEKDAY','WEEKDAYS','MON','MONDAY','TUE','TUESDAY','WED','WEDNESDAY','THU','THURSDAY','FRI','FRIDAY')
            THEN 'WKD'
            WHEN upper(service_id) IN ('SAT','SATURDAY') THEN 'SAT'
            WHEN upper(service_id) IN ('SUN','SUNDAY') THEN 'SUN'
        END AS service_id,

        CASE WHEN direction_id IN ('0','1') THEN direction_id ELSE NULL END AS direction_id,

        trip_headsign,

        CASE
            WHEN first_departure GLOB '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]'
             AND CAST(substr(first_departure, 4, 2) AS INTEGER) BETWEEN 0 AND 59
             AND CAST(substr(first_departure, 7, 2) AS INTEGER) BETWEEN 0 AND 59
            THEN first_departure
        END AS first_departure,

        CASE
            WHEN feed_start_date GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
            THEN date(substr(feed_start_date,1,4) || '-' || substr(feed_start_date,5,2) || '-' || substr(feed_start_date,7,2))
            WHEN feed_start_date GLOB '????/??/??'
            THEN date(replace(feed_start_date, '/', '-'))
            WHEN date(feed_start_date) IS NOT NULL
            THEN date(feed_start_date)
        END AS effective_day,

        feed_version,
        batch_id,
        load_at
    FROM trips_history
)

SELECT * FROM clear;

-- task: transform_update
WITH clear AS (
    SELECT
        CASE WHEN trip_id NOT GLOB '*[^0-9]*' AND trip_id <> '' AND length(ltrim(trip_id, '0')) BETWEEN 1 AND 7
             THEN printf('%07d', CAST(ltrim(trip_id, '0') AS INTEGER))
             WHEN trip_id NOT GLOB '*[^0-9]*' AND trip_id <> '' AND length(ltrim(trip_id, '0')) = 0
             THEN '0000000' END AS trip_id,

        CASE
            WHEN length(lower(replace(replace(update_id,'-',''),' ',''))) = 10
             AND lower(replace(replace(update_id,'-',''),' ','')) NOT GLOB '*[^0-9]*'
            THEN 'tu' || lower(replace(replace(update_id,'-',''),' ',''))
            WHEN length(lower(replace(replace(update_id,'-',''),' ',''))) = 12
             AND substr(lower(replace(replace(update_id,'-',''),' ','')), 1, 2) = 'tu'
             AND substr(lower(replace(replace(update_id,'-',''),' ','')), 3, 10) NOT GLOB '*[^0-9]*'
            THEN lower(replace(replace(update_id,'-',''),' ',''))
        END AS update_id,

        COALESCE(
            CASE
                WHEN start_date GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
                THEN date(substr(start_date,1,4) || '-' || substr(start_date,5,2) || '-' || substr(start_date,7,2))
                WHEN start_date GLOB '????/??/??'
                THEN date(replace(start_date, '/', '-'))
                WHEN date(start_date) IS NOT NULL
                THEN date(start_date)
            END,
            date(batch_id)
        ) AS service_day,

        CAST(route_id AS TEXT) AS route_id,

        CASE WHEN length(vehicle_id) = 4 AND vehicle_id NOT GLOB '*[^0-9]*'
             THEN CAST(vehicle_id AS TEXT) END AS vehicle_id,

        CASE
            WHEN lower(event_type) IN ('start','started','begin','began','departure','depart','commence') THEN 'start'
            WHEN lower(event_type) IN ('end','ended','finish','finished','complete','completed','arrival','arrive') THEN 'end'
            WHEN lower(event_type) IN ('cancel','cancelled','canceled','abort','aborted','void','stop','stopped') THEN 'cancel'
        END AS event_type,

        CASE
            WHEN upper(schedule_relationship) IN ('SCHEDULED','SCHEDULE','PLANNED','REGULAR') THEN 'SCHEDULED'
            WHEN upper(schedule_relationship) IN ('ADDED','ADD','EXTRA','ADDITIONAL','UNSCHEDULED') THEN 'ADDED'
            WHEN upper(schedule_relationship) IN ('CANCELED','CANCELLED','CANCEL','REMOVED','DELETED') THEN 'CANCELED'
        END AS schedule_relationship,

        -- epoch seconds (supports 10-digit seconds and 13-digit milliseconds)
        CASE
            WHEN event_time NOT GLOB '*[^0-9]*' AND length(event_time) = 13 THEN CAST(event_time AS INTEGER) / 1000
            WHEN event_time NOT GLOB '*[^0-9]*' AND length(event_time) = 10 THEN CAST(event_time AS INTEGER)
        END AS event_epoch,

        LOWER(feed) AS feed,
        batch_id,
        load_at
    FROM trip_updates_history
),

norm_status AS (
    SELECT *,
           CASE WHEN event_epoch IS NULL THEN NULL
                ELSE strftime('%Y-%m-%dT%H:%M:%SZ', event_epoch, 'unixepoch') END AS event_time_utc,
           CASE
               WHEN schedule_relationship = 'CANCELED' OR event_type = 'cancel' THEN 'cancelled'
               WHEN event_type = 'start' THEN 'started'
               WHEN event_type = 'end'   THEN 'completed'
           END AS normalized_status
    FROM clear
    WHERE trip_id IS NOT NULL
      AND service_day IS NOT NULL
)

SELECT * FROM norm_status;

-- task: trip_actuals
WITH keys AS (
    SELECT DISTINCT trip_id, service_day
    FROM transform_update
),

ranked_status AS (
    SELECT trip_id, service_day, normalized_status,
           ROW_NUMBER() OVER (
               PARTITION BY trip_id, service_day
               ORDER BY event_epoch DESC, load_at DESC, update_id DESC
           ) AS rn
    FROM transform_update
),

-- earliest valid start (>= 07:00 of service_day)
ranked_starts AS (
    SELECT trip_id, service_day, event_epoch, vehicle_id,
           ROW_NUMBER() OVER (
               PARTITION BY trip_id, service_day
               ORDER BY event_epoch ASC, load_at ASC, update_id ASC
           ) AS rn
    FROM transform_update
    WHERE normalized_status = 'started'
      AND event_epoch IS NOT NULL
      AND event_epoch >= CAST(strftime('%s', service_day || ' 07:00:00') AS INTEGER)
),

ranked_feed_routes AS (
    SELECT trip_id, service_day, route_id AS feed_route_id,
           ROW_NUMBER() OVER (
               PARTITION BY trip_id, service_day
               ORDER BY event_epoch DESC, load_at DESC, update_id DESC
           ) AS rn
    FROM transform_update
    WHERE route_id IS NOT NULL
),

-- latest version per (trip, service, effective_day)
schedule_dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY trip_id, service_id, effective_day
               ORDER BY load_at DESC, batch_id DESC
           ) AS version_row
    FROM transform_trip
    WHERE trip_id IS NOT NULL
      AND effective_day IS NOT NULL
),

-- schedule version in force on each service_day
applicable_schedule AS (
    SELECT k.trip_id, k.service_day, s.route_id, s.first_departure,
           CASE WHEN s.first_departure IS NULL THEN NULL
                ELSE datetime(
                    k.service_day,
                    '+7 hours',
                    '+' || CAST(substr(s.first_departure, 1, 2) AS INTEGER) || ' hours',
                    '+' || CAST(substr(s.first_departure, 4, 2) AS INTEGER) || ' minutes',
                    '+' || CAST(substr(s.first_departure, 7, 2) AS INTEGER) || ' seconds'
                ) END AS scheduled_dt,
           ROW_NUMBER() OVER (
               PARTITION BY k.trip_id, k.service_day
               ORDER BY s.effective_day DESC, s.load_at DESC
           ) AS schedule_row
    FROM keys k
    JOIN schedule_dedup s
      ON s.trip_id = k.trip_id
     AND s.version_row = 1
     AND s.effective_day <= k.service_day
     AND s.service_id = CASE
            WHEN CAST(strftime('%w', k.service_day) AS INTEGER) BETWEEN 1 AND 5 THEN 'WKD'
            WHEN CAST(strftime('%w', k.service_day) AS INTEGER) = 6 THEN 'SAT'
            ELSE 'SUN'
         END
),

final_rows AS (
    SELECT
        k.trip_id,
        k.service_day AS service_date,
        CASE WHEN s.trip_id IS NOT NULL THEN s.route_id ELSE fr.feed_route_id END AS route_id,
        CASE WHEN s.scheduled_dt IS NULL THEN NULL
             ELSE strftime('%Y-%m-%dT%H:%M:%SZ', s.scheduled_dt) END AS scheduled_start,
        CASE WHEN st.event_epoch IS NULL THEN NULL
             ELSE strftime('%Y-%m-%dT%H:%M:%SZ', st.event_epoch, 'unixepoch') END AS actual_start,
        CASE WHEN st.event_epoch IS NULL OR s.scheduled_dt IS NULL THEN NULL
             ELSE st.event_epoch - CAST(strftime('%s', s.scheduled_dt) AS INTEGER) END AS delay_s,
        rs.normalized_status AS status,
        CASE WHEN st.event_epoch IS NULL THEN NULL ELSE st.vehicle_id END AS vehicle_id,
        CASE WHEN s.trip_id IS NULL THEN 1 ELSE 0 END AS unscheduled
    FROM keys k
    LEFT JOIN applicable_schedule s
      ON s.trip_id = k.trip_id AND s.service_day = k.service_day AND s.schedule_row = 1
    LEFT JOIN ranked_status rs
      ON rs.trip_id = k.trip_id AND rs.service_day = k.service_day AND rs.rn = 1
    LEFT JOIN ranked_starts st
      ON st.trip_id = k.trip_id AND st.service_day = k.service_day AND st.rn = 1
    LEFT JOIN ranked_feed_routes fr
      ON fr.trip_id = k.trip_id AND fr.service_day = k.service_day AND fr.rn = 1
)

SELECT trip_id, service_date, route_id, scheduled_start, actual_start, delay_s,
       status, vehicle_id, unscheduled
FROM final_rows;
