
SELECT
  *
FROM alert_events
QUALIFY ROW_NUMBER() OVER (
      PARTITION BY svc_name
      ORDER BY fired_at) = 1
ORDER BY svc_name
