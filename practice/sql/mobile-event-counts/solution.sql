SELECT event_type, COUNT(*)
FROM event_data
WHERE tags LIKE '%mobile%'
GROUP BY 1
