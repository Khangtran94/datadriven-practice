SELECT
  endpoint,
  AVG(daily_users) AS avg_daily_active_users
FROM (
  SELECT
    endpoint,
    DATE(call_time) AS call_day,
    COUNT(DISTINCT user_id) AS daily_users
  FROM api_calls
  WHERE STRFTIME('%Y-%m', call_time) = '2026-06'
  GROUP BY endpoint, DATE(call_time)
) AS sub
GROUP BY endpoint
ORDER BY endpoint
