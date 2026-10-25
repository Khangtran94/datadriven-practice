/* dag.yml

dag: the_dwell
schedule: nightly

tasks:
  unit_visit_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [unit_visit]

  tariff_rate_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [tariff_rate]

  line_operator_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [line_operator]

  storage_charges:
    materialized: table
    depends_on:
      - unit_visit_history
      - tariff_rate_history
      - line_operator_history
*/

-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after

-- task: unit_visit_history

-- unit_visit_history.sql
-- v5: reduce repeated normalization work.
-- Output: exactly 16 columns.
-- Incremental merge key: rk.

WITH source_rows AS (
    SELECT
        json_array(
            visit_gkey, unit_nbr, line_scac,
            visit_state, tariff_cd, days_chg,
            dsch_time, gate_out_time, last_upd_time,
            remarks, _batch_id, _restated_day,
            _loaded_at
        ) AS rk,

        trim(visit_gkey) AS visit_gkey,
        upper(
            replace(
                replace(trim(unit_nbr), '-', ''),
                ' ', ''
            )
        ) AS unit_nbr,

        upper(trim(line_scac)) AS line_scac,
        lower(
            replace(
                replace(trim(visit_state), '-', '_'),
                ' ', '_'
            )
        ) AS visit_state,

        upper(trim(tariff_cd)) AS tariff_cd,
        trim(days_chg) AS days_chg,
        trim(dsch_time) AS dsch_time,
        trim(gate_out_time) AS gate_out_time,
        trim(last_upd_time) AS last_upd_time,
        trim(remarks) AS remarks,
        trim(_batch_id) AS batch_id,
        trim(_restated_day) AS restated_day,
        trim(_loaded_at) AS loaded_at

    FROM unit_visit

    {% if is_incremental() %}
    WHERE
        _loaded_at IS NULL
        OR substr(trim(_loaded_at), 1, 10) >=
            COALESCE(
                (
                    SELECT date(MAX(loaded_ts))
                    FROM {{ this }}
                ),
                '0001-01-01'
            )
        OR substr(trim(_loaded_at), 1, 10)
            NOT GLOB
            '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
    {% endif %}
),

fields_normalized AS (
    SELECT
        rk,

        CASE
            WHEN length(visit_gkey) = 8
             AND visit_gkey NOT GLOB '*[^0-9]*'
            THEN visit_gkey
        END AS visit_gkey_n,

        CASE
            WHEN length(unit_nbr) = 11
             AND substr(unit_nbr, 1, 4)
                 NOT GLOB '*[^A-Z]*'
             AND substr(unit_nbr, 5, 7)
                 NOT GLOB '*[^0-9]*'
            THEN unit_nbr
        END AS unit_nbr_n,

        CASE
            WHEN length(line_scac) = 4
             AND line_scac NOT GLOB '*[^A-Z]*'
            THEN line_scac
        END AS line_scac_n,

        CASE
            WHEN visit_state IN (
                'discharged', 'discharge',
                'disch', 'dsch'
            ) THEN 'discharged'

            WHEN visit_state IN (
                'held', 'hold', 'on_hold', 'onhold'
            ) THEN 'held'

            WHEN visit_state IN (
                'gated_out', 'gate_out', 'gateout',
                'out_gated', 'gate_out_complete'
            ) THEN 'gated_out'

            WHEN visit_state IN (
                'transshipped', 'transship',
                'transshipment', 'trans_shipped'
            ) THEN 'transshipped'
        END AS visit_state_n,

        NULLIF(tariff_cd, '') AS tariff_cd_n,

        CASE
            WHEN days_chg NOT GLOB '*[^0-9]*'
                 AND days_chg <> ''
            THEN CAST(days_chg AS INTEGER)

            WHEN substr(days_chg, 1, 1) = '-'
             AND length(days_chg) > 1
             AND substr(days_chg, 2)
                 NOT GLOB '*[^0-9]*'
            THEN CAST(days_chg AS INTEGER)
        END AS days_chg_n,

        dsch_time,
        gate_out_time,
        last_upd_time,
        remarks,
        batch_id,
        restated_day,
        loaded_at

    FROM source_rows
),

dates_prepared AS (
    SELECT
        n.*,

        CASE
            WHEN length(batch_id) = 8
             AND batch_id NOT GLOB '*[^0-9]*'
            THEN
                substr(batch_id, 1, 4) || '-' ||
                substr(batch_id, 5, 2) || '-' ||
                substr(batch_id, 7, 2)
            ELSE replace(batch_id, '/', '-')
        END AS batch_text,

        CASE
            WHEN length(restated_day) = 8
             AND restated_day NOT GLOB '*[^0-9]*'
            THEN
                substr(restated_day, 1, 4) || '-' ||
                substr(restated_day, 5, 2) || '-' ||
                substr(restated_day, 7, 2)
            ELSE replace(restated_day, '/', '-')
        END AS restated_text,

        CASE
            WHEN json_valid(remarks)
            THEN json_extract(
                CASE
                    WHEN json_valid(remarks)
                    THEN remarks
                END,
                '$.booking_ref'
            )
        END AS booking_json,

        CASE
            WHEN instr(remarks, '"booking_ref"') > 0
            THEN ltrim(
                substr(
                    remarks,
                    instr(remarks, '"booking_ref"') + 13
                ),
                ' :'
            )
        END AS booking_tail

    FROM fields_normalized AS n
),

timestamps_parsed AS (
    SELECT
        p.*,

        CASE
            WHEN dsch_time IS NULL
              OR lower(dsch_time) IN
                 ('', 'null', 'none', 'n/a', '-')
            THEN NULL

            WHEN length(dsch_time) = 13
             AND dsch_time NOT GLOB '*[^0-9]*'
            THEN strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CAST(dsch_time AS REAL) / 1000.0,
                'unixepoch'
            )

            WHEN length(dsch_time) BETWEEN 9 AND 11
             AND dsch_time NOT GLOB '*[^0-9]*'
            THEN strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CAST(dsch_time AS INTEGER),
                'unixepoch'
            )

            ELSE strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CASE
                    WHEN upper(substr(dsch_time, -1)) = 'Z'
                      OR substr(dsch_time, -6, 1)
                         IN ('+', '-')
                    THEN dsch_time
                    ELSE dsch_time || '+08:00'
                END
            )
        END AS dsch_ts,

        CASE
            WHEN gate_out_time IS NULL
              OR lower(gate_out_time) IN
                 ('', 'null', 'none', 'n/a', '-')
            THEN NULL

            WHEN length(gate_out_time) = 13
             AND gate_out_time NOT GLOB '*[^0-9]*'
            THEN strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CAST(gate_out_time AS REAL) / 1000.0,
                'unixepoch'
            )

            WHEN length(gate_out_time) BETWEEN 9 AND 11
             AND gate_out_time NOT GLOB '*[^0-9]*'
            THEN strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CAST(gate_out_time AS INTEGER),
                'unixepoch'
            )

            ELSE strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CASE
                    WHEN upper(substr(gate_out_time, -1)) = 'Z'
                      OR substr(gate_out_time, -6, 1)
                         IN ('+', '-')
                    THEN gate_out_time
                    ELSE gate_out_time || '+08:00'
                END
            )
        END AS gate_ts,

        CASE
            WHEN last_upd_time IS NULL
              OR lower(last_upd_time) IN
                 ('', 'null', 'none', 'n/a', '-')
            THEN NULL

            WHEN length(last_upd_time) = 13
             AND last_upd_time NOT GLOB '*[^0-9]*'
            THEN strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CAST(last_upd_time AS REAL) / 1000.0,
                'unixepoch'
            )

            WHEN length(last_upd_time) BETWEEN 9 AND 11
             AND last_upd_time NOT GLOB '*[^0-9]*'
            THEN strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CAST(last_upd_time AS INTEGER),
                'unixepoch'
            )

            ELSE strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CASE
                    WHEN upper(substr(last_upd_time, -1)) = 'Z'
                      OR substr(last_upd_time, -6, 1)
                         IN ('+', '-')
                    THEN last_upd_time
                    ELSE last_upd_time || '+08:00'
                END
            )
        END AS upd_ts,

        CASE
            WHEN loaded_at IS NULL
              OR lower(loaded_at) IN
                 ('', 'null', 'none', 'n/a', '-')
            THEN NULL

            WHEN length(loaded_at) = 13
             AND loaded_at NOT GLOB '*[^0-9]*'
            THEN strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CAST(loaded_at AS REAL) / 1000.0,
                'unixepoch'
            )

            WHEN length(loaded_at) BETWEEN 9 AND 11
             AND loaded_at NOT GLOB '*[^0-9]*'
            THEN strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                CAST(loaded_at AS INTEGER),
                'unixepoch'
            )

            ELSE strftime(
                '%Y-%m-%dT%H:%M:%SZ',
                loaded_at
            )
        END AS loaded_ts,

        CASE
            WHEN date(batch_text, '+0 days') = batch_text
            THEN batch_text
        END AS batch_day,

        CASE
            WHEN date(restated_text, '+0 days')
                 = restated_text
            THEN restated_text
        END AS restated_day_date

    FROM dates_prepared AS p
),

booking_normalized AS (
    SELECT
        t.*,

        trim(
            CAST(
                COALESCE(
                    booking_json,
                    CASE
                        WHEN substr(booking_tail, 1, 1) = '"'
                         AND instr(
                             substr(booking_tail, 2), '"'
                         ) > 0
                        THEN substr(
                            booking_tail,
                            2,
                            instr(
                                substr(booking_tail, 2), '"'
                            ) - 1
                        )
                    END
                ) AS TEXT
            )
        ) AS booking_candidate

    FROM timestamps_parsed AS t
)

SELECT
    rk,
    visit_gkey_n,
    unit_nbr_n,
    line_scac_n,
    visit_state_n,
    tariff_cd_n,
    days_chg_n,
    dsch_ts,
    gate_ts,

    CASE
        WHEN length(booking_candidate) = 10
         AND upper(booking_candidate) GLOB
             'BK-[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
        THEN upper(booking_candidate)

        WHEN length(booking_candidate) = 7
         AND booking_candidate GLOB
             '[0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
        THEN 'BK-' || booking_candidate
    END AS booking_ref,

    date(dsch_ts, '+2 hours')
        AS discharge_terminal_day,

    COALESCE(restated_day_date, batch_day)
        AS charge_terminal_day,

    restated_day_date,
    upd_ts,
    batch_day,
    loaded_ts

FROM booking_normalized;


-- task: tariff_rate_history
WITH raw_cleaned AS (
    SELECT json_array(tariff_cd, eff_date, rate_usd, _batch_id, _loaded_at) AS rk,
        trim(tariff_cd,char(9)||char(10)||char(13)||' ') AS tariff_cd,
        trim(eff_date,char(9)||char(10)||char(13)||' ') AS eff_date,
        trim(rate_usd,char(9)||char(10)||char(13)||' ') AS rate_usd,
        trim(_batch_id,char(9)||char(10)||char(13)||' ') AS batch_id,
        trim(_loaded_at,char(9)||char(10)||char(13)||' ') AS loaded_at
    FROM tariff_rate

{% if is_incremental() %}
 -- EARLY INGESTION FILTER: before timestamp normalization.
 -- Extra day of overlap for timezone and boundary retries.
 WHERE _loaded_at IS NULL
    OR substr(trim(_loaded_at), 1, 10) NOT GLOB
          '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
    OR substr(trim(_loaded_at), 1, 10) >= COALESCE(
          (SELECT date(MAX(loaded_ts), '-1 day') FROM {{ this }}),
          '0001-01-01'
       )
{% endif %}
),
null_normalized AS (
    SELECT rk,
        CASE WHEN lower(tariff_cd) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE tariff_cd END AS tariff_cd,
        CASE WHEN lower(eff_date) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE eff_date END AS eff_date,
        CASE WHEN lower(rate_usd) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE rate_usd END AS rate_usd,
        CASE WHEN lower(batch_id) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE batch_id END AS batch_id,
        CASE WHEN lower(loaded_at) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE loaded_at END AS loaded_at
    FROM raw_cleaned
),
fields_prepared AS (
    SELECT n.*,
           CASE WHEN length(eff_date)=8 AND eff_date NOT GLOB '*[^0-9]*'
                 THEN substr(eff_date,1,4)||'-'||substr(eff_date,5,2)||'-'||substr(eff_date,7,2)
              ELSE replace(eff_date, '/', '-') END AS eff_s,
           CASE WHEN length(batch_id)=8 AND batch_id NOT GLOB '*[^0-9]*'
                 THEN substr(batch_id,1,4)||'-'||substr(batch_id,5,2)||'-'||substr(batch_id,7,2)
              ELSE replace(batch_id, '/', '-') END AS bday_s,
           replace(rate_usd,',','.') AS rate_s,
           replace(replace(
            CASE WHEN substr(loaded_at,11,1) IN ('T','t')
                 THEN substr(loaded_at,1,10)||' '||substr(loaded_at,12)
                 ELSE loaded_at END,
            ' UTC', '+00:00'), ' GMT', '+00:00') AS load_s
    FROM null_normalized AS n
),
timezone_prepared AS (
    SELECT p.*, CASE WHEN load_s IS NULL THEN NULL
             WHEN load_s <> '' AND load_s NOT GLOB '*[^0-9]*' THEN load_s
             WHEN upper(substr(load_s,-1))='Z' OR substr(load_s,-6,1) IN ('+','-') THEN load_s
             WHEN substr(load_s,-5,1) IN ('+','-') AND substr(load_s,-4,4) NOT GLOB '*[^0-9]*'
                  THEN substr(load_s,1,length(load_s)-2)||':'||substr(load_s,-2)
             WHEN substr(load_s,-3,1) IN ('+','-') AND substr(load_s,-2,2) NOT GLOB '*[^0-9]*'
                  THEN load_s||':00'
             ELSE load_s||'+00:00' END AS load_s_z
    FROM fields_prepared AS p
),
fields_parsed AS (
    SELECT z.*,
           CASE WHEN eff_s GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                 AND length(eff_s)=10 AND date(eff_s, '+0 days')=eff_s
              THEN eff_s END AS effective_day,
           CASE WHEN bday_s GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                 AND length(bday_s)=10 AND date(bday_s, '+0 days')=bday_s
              THEN bday_s END AS batch_day,
           CASE WHEN load_s_z <> '' AND load_s_z NOT GLOB '*[^0-9]*' AND length(load_s_z)=13
                 THEN strftime('%Y-%m-%dT%H:%M:%SZ',CAST(load_s_z AS REAL)/1000.0,'unixepoch')
              WHEN load_s_z <> '' AND load_s_z NOT GLOB '*[^0-9]*' AND length(load_s_z) BETWEEN 9 AND 11
                 THEN strftime('%Y-%m-%dT%H:%M:%SZ',CAST(load_s_z AS INTEGER),'unixepoch')
              ELSE strftime('%Y-%m-%dT%H:%M:%SZ',load_s_z) END AS loaded_ts
    FROM timezone_prepared AS z
),
business_fields_normalized AS (
    SELECT rk, upper(tariff_cd) AS tariff_cd_n, effective_day,
           CASE WHEN rate_s IS NOT NULL AND rate_s <> ''
                     AND rate_s GLOB '*[0-9]*'
                     AND rate_s NOT GLOB '*[^0-9.]*'
                     AND length(rate_s)-length(replace(rate_s,'.',''))<=1
                     AND CAST(rate_s AS REAL)>=0
                THEN CAST(rate_s AS REAL) END AS rate_usd_n,
           batch_day, loaded_ts
    FROM fields_parsed
)
SELECT rk, tariff_cd_n, effective_day, rate_usd_n, batch_day, loaded_ts
FROM business_fields_normalized
{% if is_incremental() %}
WHERE loaded_ts IS NULL OR loaded_ts >= (
    SELECT COALESCE(MAX(loaded_ts),'') FROM {{ this }}
)
{% endif %};

-- task: line_operator_history
WITH raw_cleaned AS (
    SELECT json_array(line_scac, line_name, bill_to, test_flag, _batch_id, _loaded_at) AS rk,
        trim(line_scac,char(9)||char(10)||char(13)||' ') AS line_scac,
        trim(line_name,char(9)||char(10)||char(13)||' ') AS line_name,
        trim(bill_to,char(9)||char(10)||char(13)||' ') AS bill_to,
        trim(test_flag,char(9)||char(10)||char(13)||' ') AS test_flag,
        trim(_batch_id,char(9)||char(10)||char(13)||' ') AS batch_id,
        trim(_loaded_at,char(9)||char(10)||char(13)||' ') AS loaded_at
    FROM line_operator

{% if is_incremental() %}
 -- EARLY INGESTION FILTER: avoid normalizing older snapshots.
 WHERE _loaded_at IS NULL
    OR substr(trim(_loaded_at), 1, 10) NOT GLOB
          '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
    OR substr(trim(_loaded_at), 1, 10) >= COALESCE(
          (SELECT date(MAX(loaded_ts), '-1 day') FROM {{ this }}),
          '0001-01-01'
       )
{% endif %}
),
null_normalized AS (
    SELECT rk,
        CASE WHEN lower(line_scac) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE line_scac END AS line_scac,
        CASE WHEN lower(line_name) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE line_name END AS line_name,
        CASE WHEN lower(bill_to) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE bill_to END AS bill_to,
        CASE WHEN lower(test_flag) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE test_flag END AS test_flag,
        CASE WHEN lower(batch_id) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE batch_id END AS batch_id,
        CASE WHEN lower(loaded_at) IN ('', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat', '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?') THEN NULL ELSE loaded_at END AS loaded_at
    FROM raw_cleaned
),
fields_prepared AS (
    SELECT n.*,
           CASE WHEN length(batch_id)=8 AND batch_id NOT GLOB '*[^0-9]*'
                 THEN substr(batch_id,1,4)||'-'||substr(batch_id,5,2)||'-'||substr(batch_id,7,2)
              ELSE replace(batch_id, '/', '-') END AS bday_s,
           replace(replace(
            CASE WHEN substr(loaded_at,11,1) IN ('T','t')
                 THEN substr(loaded_at,1,10)||' '||substr(loaded_at,12)
                 ELSE loaded_at END,
            ' UTC', '+00:00'), ' GMT', '+00:00') AS load_s
    FROM null_normalized AS n
),
timezone_prepared AS (
    SELECT p.*, CASE WHEN load_s IS NULL THEN NULL
             WHEN load_s <> '' AND load_s NOT GLOB '*[^0-9]*' THEN load_s
             WHEN upper(substr(load_s,-1))='Z' OR substr(load_s,-6,1) IN ('+','-') THEN load_s
             WHEN substr(load_s,-5,1) IN ('+','-') AND substr(load_s,-4,4) NOT GLOB '*[^0-9]*'
                  THEN substr(load_s,1,length(load_s)-2)||':'||substr(load_s,-2)
             WHEN substr(load_s,-3,1) IN ('+','-') AND substr(load_s,-2,2) NOT GLOB '*[^0-9]*'
                  THEN load_s||':00'
             ELSE load_s||'+00:00' END AS load_s_z
    FROM fields_prepared AS p
),
fields_parsed AS (
    SELECT z.*,
           CASE WHEN bday_s GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                 AND length(bday_s)=10 AND date(bday_s, '+0 days')=bday_s
              THEN bday_s END AS batch_day,
           CASE WHEN load_s_z <> '' AND load_s_z NOT GLOB '*[^0-9]*' AND length(load_s_z)=13
                 THEN strftime('%Y-%m-%dT%H:%M:%SZ',CAST(load_s_z AS REAL)/1000.0,'unixepoch')
              WHEN load_s_z <> '' AND load_s_z NOT GLOB '*[^0-9]*' AND length(load_s_z) BETWEEN 9 AND 11
                 THEN strftime('%Y-%m-%dT%H:%M:%SZ',CAST(load_s_z AS INTEGER),'unixepoch')
              ELSE strftime('%Y-%m-%dT%H:%M:%SZ',load_s_z) END AS loaded_ts
    FROM timezone_prepared AS z
),
business_fields_normalized AS (
    SELECT rk,
           CASE WHEN length(line_scac)=4 AND upper(line_scac) NOT GLOB '*[^A-Z]*'
                THEN upper(line_scac) END AS line_scac_n,
           line_name AS line_name_n,
           CASE WHEN length(bill_to)=6 AND substr(upper(bill_to),1,1)='P'
                     AND substr(bill_to,2) NOT GLOB '*[^0-9]*'
                THEN upper(bill_to)
                WHEN length(bill_to)=5 AND bill_to NOT GLOB '*[^0-9]*'
                THEN 'P'||bill_to END AS bill_to_n,
           CASE WHEN lower(test_flag) IN ('y','yes','true','t','1') THEN 'Y'
                WHEN lower(test_flag) IN ('n','no','false','f','0') THEN 'N' END AS test_flag_n,
           batch_day, loaded_ts
    FROM fields_parsed
)
SELECT rk, line_scac_n, line_name_n, bill_to_n, test_flag_n, batch_day, loaded_ts
FROM business_fields_normalized
{% if is_incremental() %}
WHERE loaded_ts IS NULL OR loaded_ts >= (
    SELECT COALESCE(MAX(loaded_ts),'') FROM {{ this }}
)
{% endif %};

-- task: storage_charges
-- Week 6 / The Dwell. Final materialized fact, built once at the last run.
-- All *_history inputs retain only necessary normalized columns.
WITH
billing_parameters AS (
    SELECT '2026-10-19' AS close_day
),

-- Narrow visit events. Avoid SELECT * over wide persisted source history.
visit_events_prepared AS (
    SELECT visit_gkey_n AS visit_gkey,
           unit_nbr_n, line_scac_n, visit_state_n, tariff_cd_n,
           days_chg_n, dsch_ts, gate_ts, booking_ref,
           discharge_terminal_day, charge_terminal_day, restated_day_date,
           upd_ts, batch_day, loaded_ts, rk
    FROM unit_visit_history
    WHERE visit_gkey_n IS NOT NULL
),

-- ONE sort across visit history. Previously six FIRST_VALUE windows
-- each had its own ORDER BY, requiring repeated large sorts.
visit_events_ranked AS (
    SELECT e.*,
           ROW_NUMBER() OVER (
               PARTITION BY visit_gkey
               ORDER BY upd_ts DESC, batch_day DESC, loaded_ts DESC, rk DESC
           ) AS event_rank
    FROM visit_events_prepared AS e
),

-- Last state exactly as it appears in the latest event (even NULL).
-- Other attributes: last NON-NULL value, independently per column.
-- Fixed 9-digit inverted rank lets MAX select the earliest event_rank
-- without five more expensive window sorts. substr(..., 10) strips rank.
visit_attributes AS (
    SELECT visit_gkey,
           MAX(CASE WHEN event_rank = 1 THEN visit_state_n END) AS visit_state,
           substr(MAX(CASE WHEN unit_nbr_n IS NOT NULL
                      THEN printf('%09d',999999999-event_rank)||unit_nbr_n END),10) AS unit_nbr,
           substr(MAX(CASE WHEN line_scac_n IS NOT NULL
                      THEN printf('%09d',999999999-event_rank)||line_scac_n END),10) AS line_scac,
           substr(MAX(CASE WHEN gate_ts IS NOT NULL
                      THEN printf('%09d',999999999-event_rank)||gate_ts END),10) AS gate_out_time,
           substr(MAX(CASE WHEN booking_ref IS NOT NULL
                      THEN printf('%09d',999999999-event_rank)||booking_ref END),10) AS booking_ref,
           substr(MAX(CASE WHEN discharge_terminal_day IS NOT NULL
                      THEN printf('%09d',999999999-event_rank)||discharge_terminal_day END),10)
                      AS discharge_terminal_day,
           substr(MAX(CASE WHEN tariff_cd_n IS NOT NULL
                      THEN printf('%09d',999999999-event_rank)||tariff_cd_n END),10) AS tariff_cd
    FROM visit_events_ranked
    GROUP BY visit_gkey
),

-- Billing corrections/restatements: newest BUSINESS batch wins for
-- visit+charge day; a retry of an older batch must not overwrite it.
daily_charge_versions AS (
    SELECT e.visit_gkey, e.charge_terminal_day, e.days_chg_n,
           e.tariff_cd_n, e.batch_day, e.loaded_ts, e.rk,
           ROW_NUMBER() OVER (
               PARTITION BY e.visit_gkey, e.charge_terminal_day
               ORDER BY e.batch_day DESC, e.loaded_ts DESC, e.rk DESC
           ) AS charge_rank
    FROM visit_events_prepared AS e
    WHERE e.charge_terminal_day IS NOT NULL
      AND e.days_chg_n IS NOT NULL
),

daily_charge_resolved AS (
    SELECT visit_gkey, charge_terminal_day, days_chg_n AS charged_days,
           tariff_cd_n
    FROM daily_charge_versions
    WHERE charge_rank = 1
),

-- Later publication of the SAME effective_day replaces older tariff.
tariff_versions_ranked AS (
    SELECT r.*,
           ROW_NUMBER() OVER (
               PARTITION BY tariff_cd_n, effective_day
               ORDER BY batch_day DESC, loaded_ts DESC, rk DESC
           ) AS tariff_rank
    FROM tariff_rate_history AS r
    WHERE tariff_cd_n IS NOT NULL
      AND effective_day IS NOT NULL
      AND rate_usd_n IS NOT NULL
),

tariff_effective_windows AS (
    SELECT tariff_cd_n, effective_day, rate_usd_n,
           LEAD(effective_day) OVER (
               PARTITION BY tariff_cd_n ORDER BY effective_day
           ) AS next_effective_day
    FROM tariff_versions_ranked
    WHERE tariff_rank = 1
),

-- Price each daily movement once, including signed negative days.
-- Fetch tariff fallback from visit_attributes (already 1 row/visit),
-- NOT a correlated subquery for each daily charge.
daily_charges_priced AS (
    SELECT d.visit_gkey, d.charge_terminal_day, d.charged_days,
           CASE WHEN d.charged_days = 0 THEN 0
                WHEN t.rate_usd_n IS NULL THEN NULL
                ELSE CAST(ROUND(d.charged_days*t.rate_usd_n*100.0,0) AS INTEGER)
           END AS charge_cents
    FROM daily_charge_resolved AS d
    JOIN visit_attributes AS v ON v.visit_gkey = d.visit_gkey
    LEFT JOIN tariff_effective_windows AS t
        ON t.tariff_cd_n = COALESCE(d.tariff_cd_n, v.tariff_cd)
       AND d.charge_terminal_day >= t.effective_day
       AND (d.charge_terminal_day < t.next_effective_day OR t.next_effective_day IS NULL)
),

-- Start from visits to retain those with ZERO charge movements.
visit_charge_totals AS (
    SELECT v.visit_gkey,
           printf('%.2f',COALESCE(SUM(p.charge_cents),0)/100.0) AS storage_usd,
           printf('%.2f',COALESCE(SUM(CASE
                    WHEN p.charge_terminal_day <= '2026-10-19'
                    THEN p.charge_cents ELSE 0 END),0)/100.0)
                    AS storage_in_period_usd
    FROM visit_attributes AS v
    LEFT JOIN daily_charges_priced AS p ON p.visit_gkey = v.visit_gkey
    GROUP BY v.visit_gkey
),

-- Snapshot dedup: same line+batch may be manually rerun later.
-- Prune snapshots of lines with no relevant visits before window sorts.
line_snapshot_versions AS (
    SELECT line_scac_n, bill_to_n, test_flag_n, batch_day
    FROM (
        SELECT l.*,
               ROW_NUMBER() OVER (
                   PARTITION BY line_scac_n, batch_day
                   ORDER BY loaded_ts DESC, rk DESC
               ) AS line_rank
        FROM line_operator_history AS l
        WHERE l.line_scac_n IN (
            SELECT line_scac FROM visit_attributes WHERE line_scac IS NOT NULL
        ) AND batch_day IS NOT NULL
    ) AS snapshots
    WHERE line_rank = 1
),

-- Forward-fill bill_to and test_flag independently; missing text in a
-- partial update does not erase the last good value.
line_value_groups AS (
    SELECT s.*,
           SUM(CASE WHEN bill_to_n IS NOT NULL THEN 1 ELSE 0 END) OVER (
               PARTITION BY line_scac_n ORDER BY batch_day
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS bill_group,
           SUM(CASE WHEN test_flag_n IS NOT NULL THEN 1 ELSE 0 END) OVER (
               PARTITION BY line_scac_n ORDER BY batch_day
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS test_group
    FROM line_snapshot_versions AS s
),

line_billing_values AS (
    SELECT line_scac_n, batch_day,
           MAX(bill_to_n) OVER (
               PARTITION BY line_scac_n, bill_group
           ) AS bill_to,
           MAX(test_flag_n) OVER (
               PARTITION BY line_scac_n, test_group
           ) AS test_flag
    FROM line_value_groups
),

-- Effective from its terminal day until the next snapshot.
-- One earliest-known fallback interval before the first snapshot;
-- important for visits discharged before history collection began.
line_billing_windows AS (
    SELECT line_scac_n, bill_to, test_flag,
           CASE WHEN ROW_NUMBER() OVER (
                    PARTITION BY line_scac_n ORDER BY batch_day
                )=1 THEN '0001-01-01' ELSE batch_day END AS valid_from,
           LEAD(batch_day) OVER (
               PARTITION BY line_scac_n ORDER BY batch_day
           ) AS next_batch_day
    FROM line_billing_values
),

-- One 1:1 as-of interval join, no correlated MIN(batch_day) per visit.
visit_billing_parties AS (
    SELECT v.*, l.bill_to, l.test_flag
    FROM visit_attributes AS v
    LEFT JOIN line_billing_windows AS l
        ON l.line_scac_n = v.line_scac
       AND v.discharge_terminal_day >= l.valid_from
       AND (v.discharge_terminal_day < l.next_batch_day OR l.next_batch_day IS NULL)
)

-- Contract: EXACTLY 8 columns; one row/visit; exclude confirmed test lines.
SELECT v.visit_gkey AS visit_gkey,
       v.unit_nbr AS unit_nbr,
       v.visit_state AS visit_state,
       v.gate_out_time AS gate_out_time,
       v.booking_ref AS booking_ref,
       c.storage_usd AS storage_usd,
       c.storage_in_period_usd AS storage_in_period_usd,
       v.bill_to AS bill_to
FROM visit_billing_parties AS v
JOIN visit_charge_totals AS c ON c.visit_gkey = v.visit_gkey
WHERE v.test_flag IS NULL OR v.test_flag = 'N';
