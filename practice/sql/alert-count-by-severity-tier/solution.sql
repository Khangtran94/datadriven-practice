SELECT COALESCE(ack_by,'unassigned') AS responder, 
    COUNT(*) AS alert_count
FROM alert_events
GROUP BY 1
