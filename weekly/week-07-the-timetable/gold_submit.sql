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
WITH tu_source AS (
  SELECT trip_updates.*, NULL AS update_id, NULL AS trip_id, NULL AS start_date, NULL AS route_id, NULL AS vehicle_id, NULL AS event_type, NULL AS schedule_relationship, NULL AS event_time, NULL AS feed, NULL AS _batch_id, NULL AS _loaded_at FROM trip_updates
), tu_clean AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(s.update_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.update_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS update_id,
         CASE WHEN lower(trim(CAST(s.trip_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.trip_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS trip_id,
         CASE WHEN lower(trim(CAST(s.start_date AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.start_date AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS start_date,
         CASE WHEN lower(trim(CAST(s.route_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.route_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS route_id,
         CASE WHEN lower(trim(CAST(s.vehicle_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.vehicle_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS vehicle_id,
         CASE WHEN lower(trim(CAST(s.event_type AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.event_type AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS event_type,
         CASE WHEN lower(trim(CAST(s.schedule_relationship AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.schedule_relationship AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS schedule_relationship,
         CASE WHEN lower(trim(CAST(s.event_time AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.event_time AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS event_time,
         CASE WHEN lower(trim(CAST(s.feed AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.feed AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS feed,
         CASE WHEN lower(trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _batch_id,
         CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _loaded_at FROM tu_source AS s
  {% if is_incremental() %}
  WHERE strftime('%H','{{ ts }}')='13'
     OR coalesce(julianday(CASE WHEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,-1) IN ('Z','z') THEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,1,length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)-1)||'Z'
      WHEN length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)>10 AND CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END GLOB '*[+-][0-9][0-9]' THEN CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END||':00'
      WHEN length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)>10 AND CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,1,length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)-2)||':'||substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,-2)
      ELSE CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END END),julianday(substr(s._batch_id,1,10)))
       >= coalesce((SELECT max(loaded_ord) FROM {{ this }}),0)-0.000001
  {% endif %}
), typed AS MATERIALIZED (
  SELECT CASE WHEN substr(update_id,1,2)='="' AND substr(update_id,-1)='"' THEN substr(update_id,3,length(update_id)-3)
      WHEN substr(update_id,1,1)=char(39) THEN substr(update_id,2)
      WHEN instr(update_id,'.')>1 AND substr(update_id,1,instr(update_id,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(update_id,instr(update_id,'.')+1))>0
       AND substr(update_id,instr(update_id,'.')+1) NOT GLOB '*[^0]*' THEN substr(update_id,1,instr(update_id,'.')-1)
      ELSE update_id END AS update_id,CASE WHEN substr(trip_id,1,2)='="' AND substr(trip_id,-1)='"' THEN substr(trip_id,3,length(trip_id)-3)
      WHEN substr(trip_id,1,1)=char(39) THEN substr(trip_id,2)
      WHEN instr(trip_id,'.')>1 AND substr(trip_id,1,instr(trip_id,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(trip_id,instr(trip_id,'.')+1))>0
       AND substr(trip_id,instr(trip_id,'.')+1) NOT GLOB '*[^0]*' THEN substr(trip_id,1,instr(trip_id,'.')-1)
      ELSE trip_id END AS trip_id,
         CASE WHEN substr(start_date,1,2)='="' AND substr(start_date,-1)='"' THEN substr(start_date,3,length(start_date)-3)
      WHEN substr(start_date,1,1)=char(39) THEN substr(start_date,2)
      WHEN instr(start_date,'.')>1 AND substr(start_date,1,instr(start_date,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(start_date,instr(start_date,'.')+1))>0
       AND substr(start_date,instr(start_date,'.')+1) NOT GLOB '*[^0]*' THEN substr(start_date,1,instr(start_date,'.')-1)
      ELSE start_date END AS start_text,CASE WHEN substr(route_id,1,2)='="' AND substr(route_id,-1)='"' THEN substr(route_id,3,length(route_id)-3)
      WHEN substr(route_id,1,1)=char(39) THEN substr(route_id,2)
      WHEN instr(route_id,'.')>1 AND substr(route_id,1,instr(route_id,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(route_id,instr(route_id,'.')+1))>0
       AND substr(route_id,instr(route_id,'.')+1) NOT GLOB '*[^0]*' THEN substr(route_id,1,instr(route_id,'.')-1)
      ELSE route_id END AS route_id,
         CASE WHEN substr(vehicle_id,1,2)='="' AND substr(vehicle_id,-1)='"' THEN substr(vehicle_id,3,length(vehicle_id)-3)
      WHEN substr(vehicle_id,1,1)=char(39) THEN substr(vehicle_id,2)
      WHEN instr(vehicle_id,'.')>1 AND substr(vehicle_id,1,instr(vehicle_id,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(vehicle_id,instr(vehicle_id,'.')+1))>0
       AND substr(vehicle_id,instr(vehicle_id,'.')+1) NOT GLOB '*[^0]*' THEN substr(vehicle_id,1,instr(vehicle_id,'.')-1)
      ELSE vehicle_id END AS vehicle_text,CASE WHEN lower(event_type) IN ('start','started','depart','departure','departed','departed_origin','trip_start','trip started','trip_started','begin','began') THEN 'start' WHEN lower(event_type) IN ('end','ended','finish','finished','complete','completed','arrival','arrive','arrived','trip_end','trip_completed','stop') THEN 'end' WHEN lower(event_type) IN ('cancel','canceled','cancelled','cancellation','cancelled_trip','trip_cancelled','trip_canceled','cancel_trip') THEN 'cancel' WHEN upper(schedule_relationship) IN ('CANCELED','CANCELLED') THEN 'cancel' END AS event_kind,
         upper(schedule_relationship) AS relationship,lower(feed) AS feed,
         event_time,CASE WHEN length(CASE WHEN substr(event_time,1,1) IN ('+','-') THEN substr(event_time,2) ELSE event_time END)>0 AND (CASE WHEN substr(event_time,1,1) IN ('+','-') THEN substr(event_time,2) ELSE event_time END) NOT GLOB '*[^0-9]*' THEN CAST(event_time AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(event_time,1,1)='+' THEN substr(event_time,2) ELSE event_time END)
        THEN CASE WHEN json_type(CASE WHEN substr(event_time,1,1)='+' THEN substr(event_time,2) ELSE event_time END)
                       IN ('integer','real') THEN CAST(event_time AS NUMERIC) END END AS event_number,
         CASE WHEN (CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date((CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END),'+0 days')=(CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) THEN (CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) END AS batch_day,
         coalesce(julianday(CASE WHEN substr(_loaded_at,-1) IN ('Z','z') THEN substr(_loaded_at,1,length(_loaded_at)-1)||'Z'
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9]' THEN _loaded_at||':00'
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(_loaded_at,1,length(_loaded_at)-2)||':'||substr(_loaded_at,-2)
      ELSE _loaded_at END),julianday(substr(_batch_id,1,10))) AS loaded_ord
  FROM tu_clean
), normalized AS MATERIALIZED (
  SELECT update_id,trip_id,coalesce(CASE WHEN (CASE WHEN length(start_text)=8 AND start_text NOT GLOB '*[^0-9]*' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2) ELSE substr(start_text,1,10) END) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date((CASE WHEN length(start_text)=8 AND start_text NOT GLOB '*[^0-9]*' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2) ELSE substr(start_text,1,10) END),'+0 days')=(CASE WHEN length(start_text)=8 AND start_text NOT GLOB '*[^0-9]*' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2) ELSE substr(start_text,1,10) END) THEN (CASE WHEN length(start_text)=8 AND start_text NOT GLOB '*[^0-9]*' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2) ELSE substr(start_text,1,10) END) END,CASE WHEN (CASE WHEN length(CASE WHEN substr(start_text,1,1) IN ('+','-') THEN substr(start_text,2) ELSE start_text END)>0 AND (CASE WHEN substr(start_text,1,1) IN ('+','-') THEN substr(start_text,2) ELSE start_text END) NOT GLOB '*[^0-9]*' THEN CAST(start_text AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(start_text,1,1)='+' THEN substr(start_text,2) ELSE start_text END)
        THEN CASE WHEN json_type(CASE WHEN substr(start_text,1,1)='+' THEN substr(start_text,2) ELSE start_text END)
                       IN ('integer','real') THEN CAST(start_text AS NUMERIC) END END) BETWEEN 30000 AND 80000 THEN date('1899-12-30',CAST((CASE WHEN length(CASE WHEN substr(start_text,1,1) IN ('+','-') THEN substr(start_text,2) ELSE start_text END)>0 AND (CASE WHEN substr(start_text,1,1) IN ('+','-') THEN substr(start_text,2) ELSE start_text END) NOT GLOB '*[^0-9]*' THEN CAST(start_text AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(start_text,1,1)='+' THEN substr(start_text,2) ELSE start_text END)
        THEN CASE WHEN json_type(CASE WHEN substr(start_text,1,1)='+' THEN substr(start_text,2) ELSE start_text END)
                       IN ('integer','real') THEN CAST(start_text AS NUMERIC) END END) AS INTEGER)||' days') END) AS declared_day,route_id,
         CASE WHEN length(vehicle_text)>0 AND vehicle_text NOT GLOB '*[^0-9]*' THEN vehicle_text
              WHEN lower(vehicle_text) GLOB 'bus[- :_]*' OR lower(vehicle_text) GLOB 'rail[- :_]*'
              THEN CASE WHEN length(ltrim(vehicle_text,'bBuUsSrRaAiIlL -:_'))>0
                         AND ltrim(vehicle_text,'bBuUsSrRaAiIlL -:_') NOT GLOB '*[^0-9]*'
                        THEN ltrim(vehicle_text,'bBuUsSrRaAiIlL -:_') END END AS vehicle_id,
         event_kind,relationship,feed,CASE WHEN abs(event_number)<100000000000 THEN CAST(event_number AS INTEGER)
      WHEN abs(event_number)<100000000000000 THEN CAST(event_number/1000 AS INTEGER)
      WHEN abs(event_number)<100000000000000000 THEN CAST(event_number/1000000 AS INTEGER)
      WHEN abs(event_number)<100000000000000000000 THEN CAST(event_number/1000000000 AS INTEGER)
      WHEN length(event_time)>10 AND substr(event_time,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
       AND date(substr(event_time,1,10),'+0 days')=substr(event_time,1,10)
        THEN CAST(strftime('%s',CASE WHEN substr(event_time,-1) IN ('Z','z') THEN substr(event_time,1,length(event_time)-1)||'Z'
      WHEN length(event_time)>10 AND event_time GLOB '*[+-][0-9][0-9]' THEN event_time||':00'
      WHEN length(event_time)>10 AND event_time GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(event_time,1,length(event_time)-2)||':'||substr(event_time,-2)
      ELSE event_time END,CASE WHEN length(event_time)>10 AND
            (substr(event_time,-1) IN ('Z','z') OR substr(event_time,-6,1) IN ('+','-')
             OR substr(event_time,-5,1) IN ('+','-') OR substr(event_time,-3,1) IN ('+','-'))
            THEN '+0 seconds' ELSE '+7 hours' END) AS INTEGER) END AS event_s,batch_day,loaded_ord
  FROM typed WHERE trip_id IS NOT NULL
), incoming AS (
  SELECT coalesce(update_id,'@'||json_array(trip_id,declared_day,event_kind,event_s,vehicle_id,feed,batch_day)) AS event_key,
         trip_id,declared_day,route_id,vehicle_id,event_kind,relationship,feed,event_s,batch_day,loaded_ord
  FROM normalized
), candidates AS (
  SELECT * FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.* FROM {{ this }} AS h
  JOIN (SELECT DISTINCT event_key FROM incoming) AS i ON i.event_key=h.event_key
  {% endif %}
), ranked AS (
  SELECT *,row_number() OVER (PARTITION BY event_key ORDER BY loaded_ord DESC,
           (event_s IS NOT NULL) DESC,(vehicle_id IS NOT NULL) DESC,(route_id IS NOT NULL) DESC) AS rn
  FROM candidates
)
SELECT event_key,trip_id,declared_day,route_id,vehicle_id,event_kind,relationship,feed,event_s,batch_day,loaded_ord
FROM ranked WHERE rn=1;
 
-- task: trips_history
WITH tt_source AS (
  SELECT trips.*, NULL AS trip_id, NULL AS route_id, NULL AS service_id, NULL AS direction_id, NULL AS trip_headsign, NULL AS first_departure, NULL AS feed_version, NULL AS feed_start_date, NULL AS _batch_id, NULL AS _loaded_at FROM trips
), tt_clean AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(s.trip_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.trip_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS trip_id,
         CASE WHEN lower(trim(CAST(s.route_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.route_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS route_id,
         CASE WHEN lower(trim(CAST(s.service_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.service_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS service_id,
         CASE WHEN lower(trim(CAST(s.direction_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.direction_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS direction_id,
         CASE WHEN lower(trim(CAST(s.trip_headsign AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.trip_headsign AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS trip_headsign,
         CASE WHEN lower(trim(CAST(s.first_departure AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.first_departure AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS first_departure,
         CASE WHEN lower(trim(CAST(s.feed_version AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.feed_version AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS feed_version,
         CASE WHEN lower(trim(CAST(s.feed_start_date AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.feed_start_date AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS feed_start_date,
         CASE WHEN lower(trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _batch_id,
         CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _loaded_at FROM tt_source AS s
  {% if is_incremental() %}
  WHERE strftime('%H','{{ ts }}')='13'
     OR coalesce(julianday(CASE WHEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,-1) IN ('Z','z') THEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,1,length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)-1)||'Z'
      WHEN length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)>10 AND CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END GLOB '*[+-][0-9][0-9]' THEN CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END||':00'
      WHEN length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)>10 AND CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,1,length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)-2)||':'||substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,-2)
      ELSE CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END END),julianday(substr(s._batch_id,1,10)))
       >= coalesce((SELECT max(loaded_ord) FROM {{ this }}),0)-0.000001
  {% endif %}
), typed AS MATERIALIZED (
  SELECT CASE WHEN substr(trip_id,1,2)='="' AND substr(trip_id,-1)='"' THEN substr(trip_id,3,length(trip_id)-3)
      WHEN substr(trip_id,1,1)=char(39) THEN substr(trip_id,2)
      WHEN instr(trip_id,'.')>1 AND substr(trip_id,1,instr(trip_id,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(trip_id,instr(trip_id,'.')+1))>0
       AND substr(trip_id,instr(trip_id,'.')+1) NOT GLOB '*[^0]*' THEN substr(trip_id,1,instr(trip_id,'.')-1)
      ELSE trip_id END AS trip_id,CASE WHEN substr(route_id,1,2)='="' AND substr(route_id,-1)='"' THEN substr(route_id,3,length(route_id)-3)
      WHEN substr(route_id,1,1)=char(39) THEN substr(route_id,2)
      WHEN instr(route_id,'.')>1 AND substr(route_id,1,instr(route_id,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(route_id,instr(route_id,'.')+1))>0
       AND substr(route_id,instr(route_id,'.')+1) NOT GLOB '*[^0]*' THEN substr(route_id,1,instr(route_id,'.')-1)
      ELSE route_id END AS route_id,
         CASE WHEN upper(service_id) IN ('WKD','WEEKDAY','WEEKDAYS') THEN 'WKD'
              WHEN upper(service_id) IN ('SAT','SATURDAY') THEN 'SAT'
              WHEN upper(service_id) IN ('SUN','SUNDAY') THEN 'SUN' ELSE upper(service_id) END AS service_id,
         CASE WHEN substr(first_departure,1,2)='="' AND substr(first_departure,-1)='"' THEN substr(first_departure,3,length(first_departure)-3)
      WHEN substr(first_departure,1,1)=char(39) THEN substr(first_departure,2)
      WHEN instr(first_departure,'.')>1 AND substr(first_departure,1,instr(first_departure,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(first_departure,instr(first_departure,'.')+1))>0
       AND substr(first_departure,instr(first_departure,'.')+1) NOT GLOB '*[^0]*' THEN substr(first_departure,1,instr(first_departure,'.')-1)
      ELSE first_departure END AS departure_text,
         CASE WHEN substr(feed_start_date,1,2)='="' AND substr(feed_start_date,-1)='"' THEN substr(feed_start_date,3,length(feed_start_date)-3)
      WHEN substr(feed_start_date,1,1)=char(39) THEN substr(feed_start_date,2)
      WHEN instr(feed_start_date,'.')>1 AND substr(feed_start_date,1,instr(feed_start_date,'.')-1) NOT GLOB '*[^0-9]*'
       AND length(substr(feed_start_date,instr(feed_start_date,'.')+1))>0
       AND substr(feed_start_date,instr(feed_start_date,'.')+1) NOT GLOB '*[^0]*' THEN substr(feed_start_date,1,instr(feed_start_date,'.')-1)
      ELSE feed_start_date END AS start_text,feed_version,
         CASE WHEN (CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date((CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END),'+0 days')=(CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) THEN (CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) END AS batch_day,
         coalesce(julianday(CASE WHEN substr(_loaded_at,-1) IN ('Z','z') THEN substr(_loaded_at,1,length(_loaded_at)-1)||'Z'
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9]' THEN _loaded_at||':00'
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(_loaded_at,1,length(_loaded_at)-2)||':'||substr(_loaded_at,-2)
      ELSE _loaded_at END),julianday(substr(_batch_id,1,10))) AS loaded_ord
  FROM tt_clean
), clocks AS MATERIALIZED (
  SELECT *,lower(replace(departure_text,' ','')) AS clock_text,
         CASE WHEN length(CASE WHEN substr(departure_text,1,1) IN ('+','-') THEN substr(departure_text,2) ELSE departure_text END)>0 AND (CASE WHEN substr(departure_text,1,1) IN ('+','-') THEN substr(departure_text,2) ELSE departure_text END) NOT GLOB '*[^0-9]*' THEN CAST(departure_text AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(departure_text,1,1)='+' THEN substr(departure_text,2) ELSE departure_text END)
        THEN CASE WHEN json_type(CASE WHEN substr(departure_text,1,1)='+' THEN substr(departure_text,2) ELSE departure_text END)
                       IN ('integer','real') THEN CAST(departure_text AS NUMERIC) END END AS excel_clock,
         coalesce(coalesce(CASE WHEN (CASE WHEN length(start_text)=8 AND start_text NOT GLOB '*[^0-9]*' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2) ELSE substr(start_text,1,10) END) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date((CASE WHEN length(start_text)=8 AND start_text NOT GLOB '*[^0-9]*' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2) ELSE substr(start_text,1,10) END),'+0 days')=(CASE WHEN length(start_text)=8 AND start_text NOT GLOB '*[^0-9]*' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2) ELSE substr(start_text,1,10) END) THEN (CASE WHEN length(start_text)=8 AND start_text NOT GLOB '*[^0-9]*' THEN substr(start_text,1,4)||'-'||substr(start_text,5,2)||'-'||substr(start_text,7,2) ELSE substr(start_text,1,10) END) END,CASE WHEN (CASE WHEN length(CASE WHEN substr(start_text,1,1) IN ('+','-') THEN substr(start_text,2) ELSE start_text END)>0 AND (CASE WHEN substr(start_text,1,1) IN ('+','-') THEN substr(start_text,2) ELSE start_text END) NOT GLOB '*[^0-9]*' THEN CAST(start_text AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(start_text,1,1)='+' THEN substr(start_text,2) ELSE start_text END)
        THEN CASE WHEN json_type(CASE WHEN substr(start_text,1,1)='+' THEN substr(start_text,2) ELSE start_text END)
                       IN ('integer','real') THEN CAST(start_text AS NUMERIC) END END) BETWEEN 30000 AND 80000 THEN date('1899-12-30',CAST((CASE WHEN length(CASE WHEN substr(start_text,1,1) IN ('+','-') THEN substr(start_text,2) ELSE start_text END)>0 AND (CASE WHEN substr(start_text,1,1) IN ('+','-') THEN substr(start_text,2) ELSE start_text END) NOT GLOB '*[^0-9]*' THEN CAST(start_text AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(start_text,1,1)='+' THEN substr(start_text,2) ELSE start_text END)
        THEN CASE WHEN json_type(CASE WHEN substr(start_text,1,1)='+' THEN substr(start_text,2) ELSE start_text END)
                       IN ('integer','real') THEN CAST(start_text AS NUMERIC) END END) AS INTEGER)||' days') END),batch_day) AS effective_day
  FROM typed WHERE trip_id IS NOT NULL
), components AS MATERIALIZED (
  SELECT *,CASE WHEN substr(clock_text,-2) IN ('am','pm') THEN substr(clock_text,1,length(clock_text)-2)
                ELSE clock_text END AS hms,
         CASE WHEN substr(clock_text,-2) IN ('am','pm') THEN substr(clock_text,-2) END AS ampm
  FROM clocks
), pieces AS MATERIALIZED (
  SELECT *,substr(hms,1,instr(hms,':')-1) AS hh,
         CASE WHEN instr(substr(hms,instr(hms,':')+1),':')>0
                THEN substr(hms,instr(hms,':')+1,instr(substr(hms,instr(hms,':')+1),':')-1)
              ELSE substr(hms,instr(hms,':')+1) END AS mm,
         CASE WHEN instr(substr(hms,instr(hms,':')+1),':')>0
                THEN substr(hms,instr(hms,':')+1+instr(substr(hms,instr(hms,':')+1),':')) ELSE '00' END AS ss
  FROM components
), incoming AS (
  SELECT json_array(feed_version,effective_day,batch_day,loaded_ord) AS file_key,trip_id,
         route_id,service_id,effective_day,feed_version,batch_day,loaded_ord,
         CASE WHEN excel_clock>=0 AND excel_clock<7 THEN CAST(round(excel_clock*86400,0) AS INTEGER)
              WHEN instr(hms,':')>0 AND length(hh) BETWEEN 1 AND 3 AND length(mm) BETWEEN 1 AND 2 AND length(ss) BETWEEN 1 AND 2
               AND hh NOT GLOB '*[^0-9]*' AND mm NOT GLOB '*[^0-9]*' AND ss NOT GLOB '*[^0-9]*'
               AND CAST(mm AS INTEGER)<60 AND CAST(ss AS INTEGER)<60
               AND (ampm IS NULL OR CAST(hh AS INTEGER) BETWEEN 1 AND 12)
                THEN (CASE WHEN ampm IS NOT NULL THEN CAST(hh AS INTEGER)%12+CASE WHEN ampm='pm' THEN 12 ELSE 0 END
                           ELSE CAST(hh AS INTEGER) END)*3600+CAST(mm AS INTEGER)*60+CAST(ss AS INTEGER) END AS departure_s
  FROM pieces WHERE effective_day IS NOT NULL
), candidates AS (
  SELECT * FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.* FROM {{ this }} AS h
  JOIN (SELECT DISTINCT file_key,trip_id FROM incoming) AS i ON i.file_key=h.file_key AND i.trip_id=h.trip_id
  {% endif %}
), ranked AS (
  SELECT *,row_number() OVER (PARTITION BY file_key,trip_id ORDER BY (departure_s IS NOT NULL) DESC,
           (route_id IS NOT NULL) DESC) AS rn FROM candidates
)
SELECT file_key,trip_id,route_id,service_id,effective_day,feed_version,batch_day,loaded_ord,departure_s
FROM ranked WHERE rn=1;
 
-- task: rail_ready
WITH ready_source AS (
  SELECT trip_updates.*, NULL AS feed, NULL AS _batch_id FROM trip_updates
), ready_clean AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(s.feed AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.feed AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS feed,
         CASE WHEN lower(trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _batch_id FROM ready_source AS s
)
SELECT 1 WHERE EXISTS (
  SELECT 1 FROM ready_clean
  WHERE lower(feed) IN ('rail','light_rail','light rail','lrt','tram')
    AND CASE WHEN (CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date((CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END),'+0 days')=(CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) THEN (CASE WHEN length(_batch_id)=8 AND _batch_id NOT GLOB '*[^0-9]*' THEN substr(_batch_id,1,4)||'-'||substr(_batch_id,5,2)||'-'||substr(_batch_id,7,2) ELSE substr(_batch_id,1,10) END) END=date('{{ ts }}','-1 day')
);
 
-- task: timetable_versions
WITH files AS (
  SELECT file_key,effective_day,max(loaded_ord) AS loaded_ord,max(batch_day) AS batch_day,
         max(feed_version) AS feed_version FROM trips_history GROUP BY file_key,effective_day
), ranked AS (
  SELECT *,row_number() OVER (PARTITION BY effective_day ORDER BY loaded_ord DESC,batch_day DESC,feed_version DESC,file_key DESC) AS rn
  FROM files
)
SELECT file_key,effective_day,lead(effective_day,1,'9999-12-31') OVER (ORDER BY effective_day) AS next_day
FROM ranked WHERE rn=1;
 
-- task: timetable_entries
SELECT h.trip_id,h.route_id,h.service_id,h.departure_s,v.effective_day,v.next_day
FROM timetable_versions AS v JOIN trips_history AS h ON h.file_key=v.file_key;
 
-- task: resolved_events
WITH source AS MATERIALIZED (
  SELECT *,date(event_s,'unixepoch','-7 hours') AS local_day FROM trip_updates_history
), candidates AS (
  SELECT *,coalesce(declared_day,local_day,batch_day) AS candidate_day FROM source
  UNION ALL
  SELECT *,date(local_day,'-1 day') AS candidate_day FROM source WHERE declared_day IS NULL AND local_day IS NOT NULL
  UNION ALL
  SELECT *,date(local_day,'-2 days') AS candidate_day FROM source WHERE declared_day IS NULL AND local_day IS NOT NULL
), matched AS (
  SELECT c.*,t.route_id AS scheduled_route,t.departure_s,t.trip_id AS scheduled_id,
         CAST(strftime('%s',c.candidate_day||' 07:00:00') AS INTEGER)+t.departure_s AS scheduled_s,
         row_number() OVER (PARTITION BY c.event_key ORDER BY (t.trip_id IS NOT NULL) DESC,
            CASE WHEN c.declared_day IS NOT NULL THEN 0 ELSE abs(c.event_s-(CAST(strftime('%s',c.candidate_day||' 07:00:00') AS INTEGER)+t.departure_s)) END,
            c.candidate_day DESC) AS rn
  FROM candidates AS c
  LEFT JOIN timetable_entries AS t ON t.trip_id=c.trip_id
    AND c.candidate_day>=t.effective_day AND c.candidate_day<t.next_day AND (t.service_id IS NULL OR t.service_id NOT IN ('WKD','SAT','SUN') OR (t.service_id='WKD' AND strftime('%w',c.candidate_day) BETWEEN '1' AND '5') OR (t.service_id='SAT' AND strftime('%w',c.candidate_day)='6') OR (t.service_id='SUN' AND strftime('%w',c.candidate_day)='0'))
    AND (c.declared_day IS NOT NULL OR abs(c.event_s-(CAST(strftime('%s',c.candidate_day||' 07:00:00') AS INTEGER)+t.departure_s))<=43200)
), anchored AS (
  SELECT *,min(CASE WHEN event_kind='start' AND (declared_day IS NULL OR event_s>=CAST(strftime('%s',declared_day||' 07:00:00') AS INTEGER)) THEN event_s END) OVER
       (PARTITION BY trip_id,coalesce(declared_day,candidate_day),scheduled_id IS NULL) AS extra_start
  FROM matched WHERE rn=1
)
SELECT event_key,trip_id,
       CASE WHEN scheduled_id IS NOT NULL THEN candidate_day
            ELSE coalesce(date(extra_start,'unixepoch','-7 hours'),declared_day,local_day,batch_day) END AS service_date,
       CASE WHEN scheduled_id IS NOT NULL THEN scheduled_route ELSE route_id END AS route_id,
       scheduled_s,event_s,event_kind,vehicle_id,loaded_ord,
       CASE WHEN scheduled_id IS NULL THEN 1 ELSE 0 END AS unscheduled
FROM anchored;
 
-- task: trip_actuals
WITH events AS MATERIALIZED (
  SELECT * FROM resolved_events WHERE service_date BETWEEN '2026-10-02' AND '2026-10-31'
), grouped AS (
  SELECT trip_id,service_date,min(unscheduled) AS unscheduled,max(scheduled_s) AS scheduled_s,
         max(CASE WHEN unscheduled=0 THEN route_id END) AS scheduled_route,
         max(CASE WHEN route_id IS NOT NULL THEN printf('%020d',CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER))||char(31)||json_quote(route_id) END) AS route_packed,
         min(CASE WHEN event_kind='start' AND event_s>=CAST(strftime('%s',service_date||' 07:00:00') AS INTEGER) THEN printf('%012d%020d',event_s,CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER))||char(31)||json_array(event_key,vehicle_id) END) AS first_start,
         max(printf('%012d%020d',coalesce(event_s,CAST(round((loaded_ord-2440587.5)*86400,0) AS INTEGER),0),CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER))||char(31)||json_array(event_key,event_kind)) AS last_event,
         sum(CASE WHEN event_kind IS NOT NULL THEN 1 ELSE 0 END) AS known_events
  FROM events GROUP BY trip_id,service_date
), decoded AS MATERIALIZED (
  SELECT trip_id,service_date,unscheduled,scheduled_s,
         CASE WHEN unscheduled=0 THEN scheduled_route
              WHEN json_valid(substr(route_packed,22)) THEN json_extract(substr(route_packed,22),'$') END AS route_id,
         CASE WHEN first_start IS NOT NULL THEN CAST(substr(first_start,1,12) AS INTEGER) END AS actual_s,
         CASE WHEN json_valid(substr(first_start,34)) THEN json_extract(substr(first_start,34),'$[1]') END AS vehicle_id,
         CASE WHEN json_valid(substr(last_event,34)) THEN json_extract(substr(last_event,34),'$[1]') END AS last_kind
  FROM grouped WHERE known_events>0
)
SELECT trip_id,service_date,route_id,
       strftime('%Y-%m-%dT%H:%M:%SZ',scheduled_s,'unixepoch') AS scheduled_start,
       strftime('%Y-%m-%dT%H:%M:%SZ',actual_s,'unixepoch') AS actual_start,
       CASE WHEN actual_s IS NOT NULL AND scheduled_s IS NOT NULL THEN actual_s-scheduled_s END AS delay_s,
       CASE last_kind WHEN 'end' THEN 'completed' WHEN 'start' THEN 'started' WHEN 'cancel' THEN 'cancelled' END AS status,
       vehicle_id,unscheduled
FROM decoded;
