SELECT event_type
FROM event_data
GROUP BY event_type
HAVING COUNT(DISTINCT(strftime('%Y-%m',event_timestamp))) > 1
