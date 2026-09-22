SELECT *
FROM alert_events
WHERE ack_by <> 'alice' OR ack_by IS NULL
