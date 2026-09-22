with gap AS
(SELECT user_id, 
      event_timestamp,
      LAG(event_timestamp) OVER(PARTITION BY user_id ORDER BY event_timestamp) AS prev_event
FROM event_data
WHERE user_id IS NOT NULL)

SELECT user_id, 
      AVG(event_timestamp - prev_event) AS avg_progression_seconds
FROM gap
WHERE prev_event IS NOT NULL
GROUP BY user_id
ORDER BY user_id
