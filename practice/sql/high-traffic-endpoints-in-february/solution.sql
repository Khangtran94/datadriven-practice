SELECT
  COUNT(*) AS endpoint_count
FROM (
  SELECT
    endpoint
  FROM api_calls
  WHERE STRFTIME('%Y-%m', call_time) = '2026-02'
  GROUP BY endpoint
  HAVING COUNT(*) >= 100
)
