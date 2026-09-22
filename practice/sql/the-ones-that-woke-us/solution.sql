SELECT *
FROM alert_events
WHERE lower(severity) IN ('high','critical') AND extract(year from fired_at) = 2026
