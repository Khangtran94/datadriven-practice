WITH hourly AS (
  SELECT
    DATE(call_time) AS call_date,
    CAST(
      STRFTIME('%H', call_time)
      AS INTEGER
      ) AS call_hour,
    COUNT(*) AS call_count
  FROM api_calls
  GROUP BY call_date, call_hour
)
SELECT
  call_hour,
  AVG(call_count) AS avg_count
FROM hourly
GROUP BY call_hour
ORDER BY avg_count DESC, call_hour
