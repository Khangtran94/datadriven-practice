/* dag.yml
dag: the_dwell
schedule: 0 3,9,15,21 * * *
catchup: true
tasks:
  unit_visit_history:
    materialized: incremental
    depends_on:
    - unit_visit
    incremental_strategy: merge
    unique_key:
    - visit_gkey
    - effective_day
  tariff_rate_history:
    materialized: incremental
    depends_on:
    - tariff_rate
    incremental_strategy: merge
    unique_key:
    - tariff_cd
    - eff_date
  line_operator_history:
    materialized: incremental
    depends_on:
    - line_operator
    incremental_strategy: merge
    unique_key:
    - line_scac
    - snapshot_day
  tariff_intervals:
    materialized: view
    depends_on:
    - tariff_rate_history
  line_intervals:
    materialized: view
    depends_on:
    - line_operator_history
  visit_states:
    materialized: view
    depends_on:
    - unit_visit_history
  visit_costs:
    materialized: view
    depends_on:
    - unit_visit_history
    - tariff_intervals
  storage_charges:
    materialized: view
    depends_on:
    - visit_states
    - visit_costs
    - line_intervals
*/
 
-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after
 
-- task: unit_visit_history
WITH uv_source AS (
  SELECT unit_visit.*, NULL AS visit_gkey, NULL AS unit_nbr, NULL AS line_scac, NULL AS visit_state, NULL AS tariff_cd, NULL AS days_chg, NULL AS dsch_time, NULL AS gate_out_time, NULL AS last_upd_time, NULL AS remarks, NULL AS _batch_id, NULL AS _restated_day, NULL AS _loaded_at FROM unit_visit
), uv_clean AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(s.visit_gkey AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.visit_gkey AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS visit_gkey,
         CASE WHEN lower(trim(CAST(s.unit_nbr AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.unit_nbr AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS unit_nbr,
         CASE WHEN lower(trim(CAST(s.line_scac AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.line_scac AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS line_scac,
         CASE WHEN lower(trim(CAST(s.visit_state AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.visit_state AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS visit_state,
         CASE WHEN lower(trim(CAST(s.tariff_cd AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.tariff_cd AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS tariff_cd,
         CASE WHEN lower(trim(CAST(s.days_chg AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.days_chg AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS days_chg,
         CASE WHEN lower(trim(CAST(s.dsch_time AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.dsch_time AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS dsch_time,
         CASE WHEN lower(trim(CAST(s.gate_out_time AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.gate_out_time AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS gate_out_time,
         CASE WHEN lower(trim(CAST(s.last_upd_time AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.last_upd_time AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS last_upd_time,
         CASE WHEN lower(trim(CAST(s.remarks AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.remarks AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS remarks,
         CASE WHEN lower(trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _batch_id,
         CASE WHEN lower(trim(CAST(s._restated_day AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._restated_day AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _restated_day,
         CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _loaded_at FROM uv_source AS s
  {% if is_incremental() %}
  WHERE strftime('%H','{{ ts }}')='03'
     OR coalesce(julianday(CASE
      WHEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,-1) IN ('Z','z') THEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,1,length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)-1)||'Z'
      WHEN length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)>10 AND CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END GLOB '*[+-][0-9][0-9]:[0-9][0-9]' THEN CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END
      WHEN length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)>10 AND CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,1,length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)-2)||':'||substr(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END,-2)
      WHEN length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)>10 AND CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END GLOB '*[+-][0-9][0-9]' THEN CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END||':00'
      WHEN length(CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END)=10 THEN CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END||' 00:00:00'||'+00:00'
      ELSE CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END||'+00:00' END),julianday(substr(s._batch_id,1,10)))
          >= coalesce((SELECT max(loaded_ord) FROM {{ this }}),0)-0.000001
  {% endif %}
), uv_typed AS MATERIALIZED (
  SELECT CASE WHEN visit_gkey NOT GLOB '*[^0-9]*' AND length(visit_gkey)>0
              THEN coalesce(nullif(ltrim(visit_gkey,'0'),''),'0') END AS visit_gkey,
         replace(replace(replace(replace(replace(replace(upper(unit_nbr),' ',''),'-',''),char(9),''),char(10),''),char(13),''),char(160),'') AS unit_text,
         CASE WHEN upper(line_scac) GLOB '[A-Z][A-Z][A-Z][A-Z]' THEN upper(line_scac) END AS line_scac,
         CASE WHEN lower(visit_state) IN ('discharged','discharge','dsch','disch','in_yard','in yard','in-yard') THEN 'discharged' WHEN lower(visit_state) IN ('held','hold','on_hold','on hold','on-hold') THEN 'held' WHEN lower(visit_state) IN ('gated_out','gated out','gated-out','gatedout','gate_out','gate out','gate-out','gateout','out') THEN 'gated_out' WHEN lower(visit_state) IN ('transshipped','transhipped','transship','tranship','transshipment','transhipment','trans_shipped','trans-shipped') THEN 'transshipped' END AS visit_state,CASE WHEN visit_state IS NOT NULL THEN 1 ELSE 0 END AS state_seen,
         upper(tariff_cd) AS tariff_cd,CASE WHEN days_chg IS NULL THEN NULL
      WHEN length(CASE WHEN substr(days_chg,1,1) IN ('+','-') THEN substr(days_chg,2) ELSE days_chg END)>0 AND (CASE WHEN substr(days_chg,1,1) IN ('+','-') THEN substr(days_chg,2) ELSE days_chg END) NOT GLOB '*[^0-9]*' THEN CAST(days_chg AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(days_chg,1,1)='+' THEN substr(days_chg,2) ELSE days_chg END)
        THEN CASE WHEN json_type(CASE WHEN substr(days_chg,1,1)='+' THEN substr(days_chg,2) ELSE days_chg END)
                       IN ('integer','real') THEN CAST(days_chg AS NUMERIC) END END AS days_chg,
         CASE WHEN dsch_time IS NULL THEN NULL
      WHEN dsch_time NOT GLOB '*[^0-9]*' AND length(dsch_time) IN (10,13,16)
        THEN strftime('%Y-%m-%dT%H:%M:%SZ',CAST(dsch_time AS REAL)/
             CASE length(dsch_time) WHEN 10 THEN 1 WHEN 13 THEN 1000 ELSE 1000000 END,'unixepoch')
      WHEN substr(dsch_time,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
       AND date(substr(dsch_time,1,10),'+0 days')=substr(dsch_time,1,10)
        THEN strftime('%Y-%m-%dT%H:%M:%SZ',CASE
      WHEN substr(dsch_time,-1) IN ('Z','z') THEN substr(dsch_time,1,length(dsch_time)-1)||'Z'
      WHEN length(dsch_time)>10 AND dsch_time GLOB '*[+-][0-9][0-9]:[0-9][0-9]' THEN dsch_time
      WHEN length(dsch_time)>10 AND dsch_time GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(dsch_time,1,length(dsch_time)-2)||':'||substr(dsch_time,-2)
      WHEN length(dsch_time)>10 AND dsch_time GLOB '*[+-][0-9][0-9]' THEN dsch_time||':00'
      WHEN length(dsch_time)=10 THEN dsch_time||' 00:00:00'||'+08:00'
      ELSE dsch_time||'+08:00' END)
      ELSE NULL END AS dsch_time,
         CASE WHEN gate_out_time IS NULL THEN NULL
      WHEN gate_out_time NOT GLOB '*[^0-9]*' AND length(gate_out_time) IN (10,13,16)
        THEN strftime('%Y-%m-%dT%H:%M:%SZ',CAST(gate_out_time AS REAL)/
             CASE length(gate_out_time) WHEN 10 THEN 1 WHEN 13 THEN 1000 ELSE 1000000 END,'unixepoch')
      WHEN substr(gate_out_time,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
       AND date(substr(gate_out_time,1,10),'+0 days')=substr(gate_out_time,1,10)
        THEN strftime('%Y-%m-%dT%H:%M:%SZ',CASE
      WHEN substr(gate_out_time,-1) IN ('Z','z') THEN substr(gate_out_time,1,length(gate_out_time)-1)||'Z'
      WHEN length(gate_out_time)>10 AND gate_out_time GLOB '*[+-][0-9][0-9]:[0-9][0-9]' THEN gate_out_time
      WHEN length(gate_out_time)>10 AND gate_out_time GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(gate_out_time,1,length(gate_out_time)-2)||':'||substr(gate_out_time,-2)
      WHEN length(gate_out_time)>10 AND gate_out_time GLOB '*[+-][0-9][0-9]' THEN gate_out_time||':00'
      WHEN length(gate_out_time)=10 THEN gate_out_time||' 00:00:00'||'+08:00'
      ELSE gate_out_time||'+08:00' END)
      ELSE NULL END AS gate_out_time,
         CASE WHEN json_valid(remarks) THEN
           CASE WHEN json_type(remarks)='text' THEN
             CASE WHEN json_valid(json_extract(remarks,'$')) THEN json_extract(remarks,'$') ELSE '{}' END
           ELSE remarks END
         WHEN json_valid(rtrim(remarks,' '||char(9)||char(10)||char(13)||',')||'}') THEN rtrim(remarks,' '||char(9)||char(10)||char(13)||',')||'}' ELSE '{}' END AS remarks,
         CASE WHEN substr(_batch_id,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(substr(_batch_id,1,10),'+0 days')=substr(_batch_id,1,10) THEN substr(_batch_id,1,10) END AS source_day,
         coalesce(CASE WHEN substr(_restated_day,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(substr(_restated_day,1,10),'+0 days')=substr(_restated_day,1,10) THEN substr(_restated_day,1,10) END,CASE WHEN substr(_batch_id,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(substr(_batch_id,1,10),'+0 days')=substr(_batch_id,1,10) THEN substr(_batch_id,1,10) END) AS effective_day,
         coalesce(julianday(CASE
      WHEN substr(_loaded_at,-1) IN ('Z','z') THEN substr(_loaded_at,1,length(_loaded_at)-1)||'Z'
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9]:[0-9][0-9]' THEN _loaded_at
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(_loaded_at,1,length(_loaded_at)-2)||':'||substr(_loaded_at,-2)
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9]' THEN _loaded_at||':00'
      WHEN length(_loaded_at)=10 THEN _loaded_at||' 00:00:00'||'+00:00'
      ELSE _loaded_at||'+00:00' END),julianday(substr(_batch_id,1,10))) AS loaded_ord
  FROM uv_clean
), uv_values AS (
  SELECT *,CASE WHEN unit_text GLOB '[A-Z][A-Z][A-Z][UJZ][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' AND ((unicode(substr(unit_text,1,1))-55+(unicode(substr(unit_text,1,1))-56)/10)*1+(unicode(substr(unit_text,2,1))-55+(unicode(substr(unit_text,2,1))-56)/10)*2+(unicode(substr(unit_text,3,1))-55+(unicode(substr(unit_text,3,1))-56)/10)*4+(unicode(substr(unit_text,4,1))-55+(unicode(substr(unit_text,4,1))-56)/10)*8+CAST(substr(unit_text,5,1) AS INTEGER)*16+CAST(substr(unit_text,6,1) AS INTEGER)*32+CAST(substr(unit_text,7,1) AS INTEGER)*64+CAST(substr(unit_text,8,1) AS INTEGER)*128+CAST(substr(unit_text,9,1) AS INTEGER)*256+CAST(substr(unit_text,10,1) AS INTEGER)*512)%11%10=CAST(substr(unit_text,11,1) AS INTEGER) THEN unit_text END AS unit_nbr,
         CASE WHEN json_type(remarks,'$.booking_ref') IN ('true','false') THEN json_type(remarks,'$.booking_ref')
              WHEN json_type(remarks,'$.booking_ref') IN ('text','integer','real')
                THEN CAST(json_extract(remarks,'$.booking_ref') AS TEXT) END AS booking_ref,
         CASE WHEN json_type(remarks,'$.booking_ref') IS NOT NULL THEN 1 ELSE 0 END AS booking_seen
  FROM uv_typed
), incoming AS (
  SELECT visit_gkey,effective_day,unit_nbr,CASE WHEN unit_nbr IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS unit_nbr_ver,line_scac,CASE WHEN line_scac IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS line_scac_ver,visit_state,CASE WHEN state_seen=1 THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS visit_state_ver,tariff_cd,CASE WHEN tariff_cd IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS tariff_cd_ver,days_chg,CASE WHEN days_chg IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS days_chg_ver,dsch_time,CASE WHEN dsch_time IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS dsch_time_ver,gate_out_time,CASE WHEN gate_out_time IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS gate_out_time_ver,booking_ref,CASE WHEN booking_seen=1 THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS booking_ref_ver,source_day,loaded_ord FROM uv_values
  WHERE visit_gkey IS NOT NULL AND source_day IS NOT NULL AND effective_day IS NOT NULL
), candidates AS (
  SELECT visit_gkey,effective_day,unit_nbr,unit_nbr_ver,line_scac,line_scac_ver,visit_state,visit_state_ver,tariff_cd,tariff_cd_ver,days_chg,days_chg_ver,dsch_time,dsch_time_ver,gate_out_time,gate_out_time_ver,booking_ref,booking_ref_ver,source_day,loaded_ord FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.visit_gkey,h.effective_day,h.unit_nbr,h.unit_nbr_ver,h.line_scac,h.line_scac_ver,h.visit_state,h.visit_state_ver,h.tariff_cd,h.tariff_cd_ver,h.days_chg,h.days_chg_ver,h.dsch_time,h.dsch_time_ver,h.gate_out_time,h.gate_out_time_ver,h.booking_ref,h.booking_ref_ver,h.source_day,h.loaded_ord FROM {{ this }} AS h
  JOIN (SELECT DISTINCT visit_gkey,effective_day FROM incoming) AS k
    ON h.visit_gkey=k.visit_gkey AND h.effective_day=k.effective_day
  {% endif %}
), grouped AS (
  SELECT visit_gkey,effective_day,
         max(CASE WHEN unit_nbr_ver IS NOT NULL THEN printf('%019d',unit_nbr_ver)||char(31)||json_quote(unit_nbr) END) AS unit_nbr_packed,
         max(CASE WHEN line_scac_ver IS NOT NULL THEN printf('%019d',line_scac_ver)||char(31)||json_quote(line_scac) END) AS line_scac_packed,
         max(CASE WHEN visit_state_ver IS NOT NULL THEN printf('%019d',visit_state_ver)||char(31)||json_quote(visit_state) END) AS visit_state_packed,
         max(CASE WHEN tariff_cd_ver IS NOT NULL THEN printf('%019d',tariff_cd_ver)||char(31)||json_quote(tariff_cd) END) AS tariff_cd_packed,
         max(CASE WHEN days_chg_ver IS NOT NULL THEN printf('%019d',days_chg_ver)||char(31)||json_quote(days_chg) END) AS days_chg_packed,
         max(CASE WHEN dsch_time_ver IS NOT NULL THEN printf('%019d',dsch_time_ver)||char(31)||json_quote(dsch_time) END) AS dsch_time_packed,
         max(CASE WHEN gate_out_time_ver IS NOT NULL THEN printf('%019d',gate_out_time_ver)||char(31)||json_quote(gate_out_time) END) AS gate_out_time_packed,
         max(CASE WHEN booking_ref_ver IS NOT NULL THEN printf('%019d',booking_ref_ver)||char(31)||json_quote(booking_ref) END) AS booking_ref_packed,max(source_day) AS source_day,max(loaded_ord) AS loaded_ord
  FROM candidates GROUP BY visit_gkey,effective_day
)
SELECT visit_gkey,effective_day,
       CASE WHEN json_valid(substr(unit_nbr_packed,instr(unit_nbr_packed,char(31))+1)) THEN json_extract(substr(unit_nbr_packed,instr(unit_nbr_packed,char(31))+1),'$') END AS unit_nbr, CAST(substr(unit_nbr_packed,1,instr(unit_nbr_packed,char(31))-1) AS INTEGER) AS unit_nbr_ver, CASE WHEN json_valid(substr(line_scac_packed,instr(line_scac_packed,char(31))+1)) THEN json_extract(substr(line_scac_packed,instr(line_scac_packed,char(31))+1),'$') END AS line_scac, CAST(substr(line_scac_packed,1,instr(line_scac_packed,char(31))-1) AS INTEGER) AS line_scac_ver, CASE WHEN json_valid(substr(visit_state_packed,instr(visit_state_packed,char(31))+1)) THEN json_extract(substr(visit_state_packed,instr(visit_state_packed,char(31))+1),'$') END AS visit_state, CAST(substr(visit_state_packed,1,instr(visit_state_packed,char(31))-1) AS INTEGER) AS visit_state_ver, CASE WHEN json_valid(substr(tariff_cd_packed,instr(tariff_cd_packed,char(31))+1)) THEN json_extract(substr(tariff_cd_packed,instr(tariff_cd_packed,char(31))+1),'$') END AS tariff_cd, CAST(substr(tariff_cd_packed,1,instr(tariff_cd_packed,char(31))-1) AS INTEGER) AS tariff_cd_ver, CASE WHEN json_valid(substr(days_chg_packed,instr(days_chg_packed,char(31))+1)) THEN json_extract(substr(days_chg_packed,instr(days_chg_packed,char(31))+1),'$') END AS days_chg, CAST(substr(days_chg_packed,1,instr(days_chg_packed,char(31))-1) AS INTEGER) AS days_chg_ver, CASE WHEN json_valid(substr(dsch_time_packed,instr(dsch_time_packed,char(31))+1)) THEN json_extract(substr(dsch_time_packed,instr(dsch_time_packed,char(31))+1),'$') END AS dsch_time, CAST(substr(dsch_time_packed,1,instr(dsch_time_packed,char(31))-1) AS INTEGER) AS dsch_time_ver, CASE WHEN json_valid(substr(gate_out_time_packed,instr(gate_out_time_packed,char(31))+1)) THEN json_extract(substr(gate_out_time_packed,instr(gate_out_time_packed,char(31))+1),'$') END AS gate_out_time, CAST(substr(gate_out_time_packed,1,instr(gate_out_time_packed,char(31))-1) AS INTEGER) AS gate_out_time_ver, CASE WHEN json_valid(substr(booking_ref_packed,instr(booking_ref_packed,char(31))+1)) THEN json_extract(substr(booking_ref_packed,instr(booking_ref_packed,char(31))+1),'$') END AS booking_ref, CAST(substr(booking_ref_packed,1,instr(booking_ref_packed,char(31))-1) AS INTEGER) AS booking_ref_ver,source_day,loaded_ord FROM grouped;
 
-- task: tariff_rate_history
WITH tr_source AS (
  SELECT tariff_rate.*, NULL AS tariff_cd, NULL AS eff_date, NULL AS rate_usd, NULL AS _batch_id, NULL AS _loaded_at FROM tariff_rate
), tr_clean AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(s.tariff_cd AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.tariff_cd AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS tariff_cd,
         CASE WHEN lower(trim(CAST(s.eff_date AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.eff_date AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS eff_date,
         CASE WHEN lower(trim(CAST(s.rate_usd AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.rate_usd AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS rate_usd,
         CASE WHEN lower(trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _batch_id,
         CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _loaded_at FROM tr_source AS s
), incoming AS (
  SELECT upper(tariff_cd) AS tariff_cd,CASE WHEN substr(eff_date,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(substr(eff_date,1,10),'+0 days')=substr(eff_date,1,10) THEN substr(eff_date,1,10) END AS eff_date,
         CASE WHEN rate_usd IS NULL THEN NULL
      WHEN length(CASE WHEN substr(rate_usd,1,1) IN ('+','-') THEN substr(rate_usd,2) ELSE rate_usd END)>0 AND (CASE WHEN substr(rate_usd,1,1) IN ('+','-') THEN substr(rate_usd,2) ELSE rate_usd END) NOT GLOB '*[^0-9]*' THEN CAST(rate_usd AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(rate_usd,1,1)='+' THEN substr(rate_usd,2) ELSE rate_usd END)
        THEN CASE WHEN json_type(CASE WHEN substr(rate_usd,1,1)='+' THEN substr(rate_usd,2) ELSE rate_usd END)
                       IN ('integer','real') THEN CAST(rate_usd AS NUMERIC) END END AS rate_usd,
         coalesce(julianday(CASE
      WHEN substr(_loaded_at,-1) IN ('Z','z') THEN substr(_loaded_at,1,length(_loaded_at)-1)||'Z'
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9]:[0-9][0-9]' THEN _loaded_at
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(_loaded_at,1,length(_loaded_at)-2)||':'||substr(_loaded_at,-2)
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9]' THEN _loaded_at||':00'
      WHEN length(_loaded_at)=10 THEN _loaded_at||' 00:00:00'||'+00:00'
      ELSE _loaded_at||'+00:00' END),julianday(substr(_batch_id,1,10))) AS loaded_ord
  FROM tr_clean
), candidates AS (
  SELECT * FROM incoming WHERE tariff_cd IS NOT NULL AND eff_date IS NOT NULL AND rate_usd>=0 AND rate_usd<1e290
  {% if is_incremental() %}
  UNION ALL
  SELECT tariff_cd,eff_date,rate_usd,loaded_ord FROM {{ this }}
  {% endif %}
), ranked AS (
  SELECT *,row_number() OVER (PARTITION BY tariff_cd,eff_date ORDER BY loaded_ord DESC,rate_usd DESC) AS rn FROM candidates
)
SELECT tariff_cd,eff_date,rate_usd,
       CASE WHEN rate_usd*1000000000<=9223372036854775807 THEN CAST(round(rate_usd*1000000000,0) AS INTEGER)
            ELSE round(rate_usd*1000000000,0) END AS rate_nanos,loaded_ord
FROM ranked WHERE rn=1;
 
-- task: line_operator_history
WITH lo_source AS (
  SELECT line_operator.*, NULL AS line_scac, NULL AS bill_to, NULL AS test_flag, NULL AS _batch_id, NULL AS _loaded_at FROM line_operator
), lo_clean AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(s.line_scac AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.line_scac AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS line_scac,
         CASE WHEN lower(trim(CAST(s.bill_to AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.bill_to AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS bill_to,
         CASE WHEN lower(trim(CAST(s.test_flag AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s.test_flag AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS test_flag,
         CASE WHEN lower(trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._batch_id AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _batch_id,
         CASE WHEN lower(trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160))) IN ('','null','none','nil','n/a','na','nan','undefined','\n','\\n') THEN NULL ELSE trim(CAST(s._loaded_at AS TEXT),' '||char(9)||char(10)||char(13)||char(160)) END AS _loaded_at FROM lo_source AS s
), lo_typed AS MATERIALIZED (
  SELECT upper(line_scac) AS line_scac,upper(bill_to) AS bill_to,
         CASE WHEN lower(test_flag) IN ('y','yes','true','t','1') THEN 1
              WHEN lower(test_flag) IN ('n','no','false','f','0') THEN 0 END AS test_flag,
         CASE WHEN substr(_batch_id,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(substr(_batch_id,1,10),'+0 days')=substr(_batch_id,1,10) THEN substr(_batch_id,1,10) END AS snapshot_day,CASE WHEN substr(_batch_id,1,10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND date(substr(_batch_id,1,10),'+0 days')=substr(_batch_id,1,10) THEN substr(_batch_id,1,10) END AS source_day,
         coalesce(julianday(CASE
      WHEN substr(_loaded_at,-1) IN ('Z','z') THEN substr(_loaded_at,1,length(_loaded_at)-1)||'Z'
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9]:[0-9][0-9]' THEN _loaded_at
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(_loaded_at,1,length(_loaded_at)-2)||':'||substr(_loaded_at,-2)
      WHEN length(_loaded_at)>10 AND _loaded_at GLOB '*[+-][0-9][0-9]' THEN _loaded_at||':00'
      WHEN length(_loaded_at)=10 THEN _loaded_at||' 00:00:00'||'+00:00'
      ELSE _loaded_at||'+00:00' END),julianday(substr(_batch_id,1,10))) AS loaded_ord
  FROM lo_clean
), incoming AS (
  SELECT line_scac,snapshot_day,bill_to,CASE WHEN bill_to IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS bill_to_ver,
         test_flag,CASE WHEN test_flag IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000+CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS test_flag_ver,source_day,loaded_ord
  FROM lo_typed WHERE line_scac GLOB '[A-Z][A-Z][A-Z][A-Z]' AND snapshot_day IS NOT NULL
), candidates AS (
  SELECT line_scac,snapshot_day,bill_to,bill_to_ver,test_flag,test_flag_ver,source_day,loaded_ord FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.line_scac,h.snapshot_day,h.bill_to,h.bill_to_ver,h.test_flag,h.test_flag_ver,h.source_day,h.loaded_ord FROM {{ this }} AS h
  JOIN (SELECT DISTINCT line_scac,snapshot_day FROM incoming) AS k
    ON h.line_scac=k.line_scac AND h.snapshot_day=k.snapshot_day
  {% endif %}
), grouped AS (
  SELECT line_scac,snapshot_day,
         max(CASE WHEN bill_to_ver IS NOT NULL THEN printf('%019d',bill_to_ver)||char(31)||json_quote(bill_to) END) AS bill_to_packed,
         max(CASE WHEN test_flag_ver IS NOT NULL THEN printf('%019d',test_flag_ver)||char(31)||json_quote(test_flag) END) AS test_flag_packed,max(source_day) AS source_day,max(loaded_ord) AS loaded_ord
  FROM candidates GROUP BY line_scac,snapshot_day
)
SELECT line_scac,snapshot_day,
       CASE WHEN json_valid(substr(bill_to_packed,instr(bill_to_packed,char(31))+1)) THEN json_extract(substr(bill_to_packed,instr(bill_to_packed,char(31))+1),'$') END AS bill_to, CAST(substr(bill_to_packed,1,instr(bill_to_packed,char(31))-1) AS INTEGER) AS bill_to_ver, CASE WHEN json_valid(substr(test_flag_packed,instr(test_flag_packed,char(31))+1)) THEN json_extract(substr(test_flag_packed,instr(test_flag_packed,char(31))+1),'$') END AS test_flag, CAST(substr(test_flag_packed,1,instr(test_flag_packed,char(31))-1) AS INTEGER) AS test_flag_ver,source_day,loaded_ord FROM grouped;
 
-- task: tariff_intervals
SELECT tariff_cd,eff_date,rate_nanos,
       lead(eff_date,1,'9999-12-31') OVER (PARTITION BY tariff_cd ORDER BY eff_date) AS next_date
FROM tariff_rate_history;
 
-- task: line_intervals
WITH marked AS (
  SELECT *,count(bill_to) OVER (PARTITION BY line_scac ORDER BY snapshot_day) AS bill_group,
           count(test_flag) OVER (PARTITION BY line_scac ORDER BY snapshot_day) AS test_group
  FROM line_operator_history
)
SELECT line_scac,snapshot_day,
       lead(snapshot_day,1,'9999-12-31') OVER (PARTITION BY line_scac ORDER BY snapshot_day) AS next_day,
       max(bill_to) OVER (PARTITION BY line_scac,bill_group) AS bill_to,
       max(test_flag) OVER (PARTITION BY line_scac,test_group) AS test_flag
FROM marked;
 
-- task: visit_states
WITH grouped AS (
  SELECT visit_gkey,max(CASE WHEN unit_nbr_ver IS NOT NULL THEN printf('%019d',unit_nbr_ver)||char(31)||json_quote(unit_nbr) END) AS unit_nbr_packed,
         max(CASE WHEN line_scac_ver IS NOT NULL THEN printf('%019d',line_scac_ver)||char(31)||json_quote(line_scac) END) AS line_scac_packed,
         max(CASE WHEN visit_state_ver IS NOT NULL THEN printf('%019d',visit_state_ver)||char(31)||json_quote(visit_state) END) AS visit_state_packed,
         max(CASE WHEN dsch_time_ver IS NOT NULL THEN printf('%019d',dsch_time_ver)||char(31)||json_quote(dsch_time) END) AS dsch_time_packed,
         max(CASE WHEN gate_out_time_ver IS NOT NULL THEN printf('%019d',gate_out_time_ver)||char(31)||json_quote(gate_out_time) END) AS gate_out_time_packed,
         max(CASE WHEN booking_ref_ver IS NOT NULL THEN printf('%019d',booking_ref_ver)||char(31)||json_quote(booking_ref) END) AS booking_ref_packed FROM unit_visit_history GROUP BY visit_gkey
)
SELECT visit_gkey,CASE WHEN json_valid(substr(unit_nbr_packed,instr(unit_nbr_packed,char(31))+1)) THEN json_extract(substr(unit_nbr_packed,instr(unit_nbr_packed,char(31))+1),'$') END AS unit_nbr,CASE WHEN json_valid(substr(line_scac_packed,instr(line_scac_packed,char(31))+1)) THEN json_extract(substr(line_scac_packed,instr(line_scac_packed,char(31))+1),'$') END AS line_scac,CASE WHEN json_valid(substr(visit_state_packed,instr(visit_state_packed,char(31))+1)) THEN json_extract(substr(visit_state_packed,instr(visit_state_packed,char(31))+1),'$') END AS visit_state,CASE WHEN json_valid(substr(dsch_time_packed,instr(dsch_time_packed,char(31))+1)) THEN json_extract(substr(dsch_time_packed,instr(dsch_time_packed,char(31))+1),'$') END AS dsch_time,CASE WHEN json_valid(substr(gate_out_time_packed,instr(gate_out_time_packed,char(31))+1)) THEN json_extract(substr(gate_out_time_packed,instr(gate_out_time_packed,char(31))+1),'$') END AS gate_out_time,CASE WHEN json_valid(substr(booking_ref_packed,instr(booking_ref_packed,char(31))+1)) THEN json_extract(substr(booking_ref_packed,instr(booking_ref_packed,char(31))+1),'$') END AS booking_ref FROM grouped;
 
-- task: visit_costs
WITH marked AS (
  SELECT visit_gkey,effective_day,days_chg,tariff_cd,
         count(tariff_cd) OVER (PARTITION BY visit_gkey ORDER BY effective_day) AS tariff_group
  FROM unit_visit_history
), daily AS (
  SELECT visit_gkey,effective_day,days_chg,
         max(tariff_cd) OVER (PARTITION BY visit_gkey,tariff_group) AS tariff_cd
  FROM marked
), priced AS MATERIALIZED (
  SELECT d.visit_gkey,d.effective_day,
         CASE WHEN abs(d.days_chg*r.rate_nanos)<=10000000000000
                THEN CAST(round(d.days_chg*r.rate_nanos,0) AS INTEGER)
              WHEN abs(d.days_chg*r.rate_nanos)<1e308 THEN round(d.days_chg*r.rate_nanos,0)
              ELSE 0 END AS nanos
  FROM daily AS d
  LEFT JOIN tariff_intervals AS r ON r.tariff_cd=d.tariff_cd
    AND d.effective_day>=r.eff_date AND d.effective_day<r.next_date
), sums AS (
  SELECT visit_gkey,SUM(CASE WHEN (1=1) AND typeof(nanos)='integer' AND nanos BETWEEN -10000000000000 AND 10000000000000 THEN nanos ELSE 0 END) AS all_small,TOTAL(CASE WHEN (1=1) AND NOT (typeof(nanos)='integer' AND nanos BETWEEN -10000000000000 AND 10000000000000) THEN nanos ELSE 0 END) AS all_large,SUM(CASE WHEN (1=1) AND NOT (typeof(nanos)='integer' AND nanos BETWEEN -10000000000000 AND 10000000000000) THEN 1 ELSE 0 END) AS all_large_count,SUM(CASE WHEN (effective_day<='2026-10-19') AND typeof(nanos)='integer' AND nanos BETWEEN -10000000000000 AND 10000000000000 THEN nanos ELSE 0 END) AS period_small,TOTAL(CASE WHEN (effective_day<='2026-10-19') AND NOT (typeof(nanos)='integer' AND nanos BETWEEN -10000000000000 AND 10000000000000) THEN nanos ELSE 0 END) AS period_large,SUM(CASE WHEN (effective_day<='2026-10-19') AND NOT (typeof(nanos)='integer' AND nanos BETWEEN -10000000000000 AND 10000000000000) THEN 1 ELSE 0 END) AS period_large_count FROM priced GROUP BY visit_gkey
)
SELECT visit_gkey,CASE WHEN all_large_count=0 THEN all_small ELSE all_small+all_large END AS all_nanos,
       CASE WHEN period_large_count=0 THEN period_small ELSE period_small+period_large END AS period_nanos
FROM sums;
 
-- task: storage_charges
WITH states AS MATERIALIZED (
  SELECT *,date(dsch_time,'+2 hours') AS discharge_day FROM visit_states
), costs AS MATERIALIZED (
  SELECT * FROM visit_costs
), billed AS MATERIALIZED (
  SELECT v.visit_gkey,v.unit_nbr,v.visit_state,v.gate_out_time,v.booking_ref,l.bill_to,
         CASE WHEN typeof(coalesce(c.all_nanos,0))='integer' THEN
           (CASE WHEN coalesce(c.all_nanos,0)<0 THEN -1 ELSE 1 END)*
           (abs(coalesce(c.all_nanos,0))/10000000+CASE WHEN abs(coalesce(c.all_nanos,0))%10000000>=5000000 THEN 1 ELSE 0 END)
         ELSE round(coalesce(c.all_nanos,0)/10000000.0,0) END AS all_cents,CASE WHEN typeof(coalesce(c.period_nanos,0))='integer' THEN
           (CASE WHEN coalesce(c.period_nanos,0)<0 THEN -1 ELSE 1 END)*
           (abs(coalesce(c.period_nanos,0))/10000000+CASE WHEN abs(coalesce(c.period_nanos,0))%10000000>=5000000 THEN 1 ELSE 0 END)
         ELSE round(coalesce(c.period_nanos,0)/10000000.0,0) END AS period_cents
  FROM states AS v
  LEFT JOIN costs AS c ON c.visit_gkey=v.visit_gkey
  LEFT JOIN line_intervals AS l ON l.line_scac=v.line_scac
    AND v.discharge_day>=l.snapshot_day AND v.discharge_day<l.next_day
  WHERE coalesce(l.test_flag,0)=0
)
SELECT visit_gkey,unit_nbr,visit_state,gate_out_time,booking_ref,
       printf('%.2f',all_cents/100.0) AS storage_usd,
       printf('%.2f',period_cents/100.0) AS storage_in_period_usd,bill_to
FROM billed;
