with total AS
(SELECT event_timestamp, event_type, tags,
    CASE WHEN event_type = 'open' THEN 1 ELSE 0 END AS num_opens,
    CASE WHEN event_type = 'crash' THEN 1 ELSE 0 END AS num_crashes
FROM event_data
WHERE event_type IN ('open','crash'))

SELECT event_timestamp, tags, num_opens, num_crashes, 
    num_crashes / num_opens AS crash_rate
FROM total
ORDER BY 1
